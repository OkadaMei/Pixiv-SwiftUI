import argparse
import logging
import os
import signal
import sys
import time

from dotenv import load_dotenv
from src.api.auth import AuthAPI
from src.api.client import NetworkClient
from src.api.search import SearchAPI
from src.models import PixivTag
from src.sqlite_storage import SQLiteStorage

# 全局停止标志
should_stop = False


def signal_handler(signum, frame):
    """处理 Ctrl+C 信号"""
    global should_stop
    should_stop = True
    logging.info("\n收到退出信号，正在完成当前批次并退出...")


def main():
    # 1. 加载环境变量
    load_dotenv()

    # 2. 配置日志
    log_level_str = os.getenv("LOG_LEVEL", "INFO").upper()
    log_level = getattr(logging, log_level_str, logging.INFO)

    logging.basicConfig(
        level=log_level,
        format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
        handlers=[
            logging.StreamHandler(sys.stdout),
        ],
    )
    logger = logging.getLogger("search_script")

    # 3. 解析命令行参数
    parser = argparse.ArgumentParser(
        description="搜索指定标签的插画并收集相关标签到数据库"
    )
    parser.add_argument("tag", help="要搜索的标签关键词")
    parser.add_argument("--limit", type=int, default=30, help="每页结果数量 (默认: 30)")
    args = parser.parse_args()

    # 4. 初始化组件
    wait_time_429 = int(os.getenv("PIXIV_429_WAIT_TIME", "300"))
    max_429_retries = int(os.getenv("PIXIV_429_MAX_RETRIES", "3"))
    sqlite_path = os.getenv("SQLITE_DB_PATH", "data/pixiv_tags.db")

    client = NetworkClient(wait_time_429=wait_time_429, max_429_retries=max_429_retries)
    auth = AuthAPI(client)
    auth.setup_token_refresh()  # 设置自动刷新 token
    search = SearchAPI(client)
    storage = SQLiteStorage(sqlite_path)

    # 5. 注册信号处理器
    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)

    # 6. 登录
    try:
        logger.info("正在使用 refresh_token 登录...")
        auth.login_with_refresh_token()
        logger.info("登录成功")
    except Exception as e:
        logger.error(f"登录失败: {e}")
        sys.exit(1)

    # 7. 搜索循环
    offset = 0
    total_illusts_processed = 0
    logger.info(f"开始遍历标签 '{args.tag}' 的所有插画...")

    # 时间分段逻辑：如果遇到 next_url 为 null 但明显没抓完的情况
    import datetime

    current_end_date = None  # 默认不限制

    try:
        while not should_stop:
            logger.info(
                f"正在获取第 {offset} 个偏移量开始的页面... (日期截止: {current_end_date or '不限'})"
            )

            # 调用 SearchAPI 进行搜索
            response = search.search_illust_by_tag(
                args.tag, offset=offset, limit=args.limit, end_date=current_end_date
            )

            # 调试日志
            import json

            logger.debug(
                f"API 响应摘要: illusts={len(response.get('illusts', []))}, next_url={response.get('next_url')}"
            )

            illusts = response.get("illusts", [])

            if not illusts:
                if current_end_date:  # 如果已经是在分段搜索了
                    logger.info("当前时间段没有更多结果。")
                else:
                    logger.info("没有更多结果。")
                break

            # 提取本页所有插画的标签
            all_tags_to_upsert = []
            page_unique_tag_names = set()
            last_illust_date = None

            for illust in illusts:
                # 记录最后一个插画的日期，用于分段
                last_illust_date = illust.get("create_date")
                logger.debug(
                    f"作品 ID: {illust.get('id')}, 创建日期: {last_illust_date}"
                )

                # 自动跳过 search_script 自己添加的调试逻辑干扰
                for tag_data in illust.get("tags", []):
                    tag = PixivTag.from_api_response(tag_data)
                    all_tags_to_upsert.append(tag)
                    page_unique_tag_names.add(tag.name)

            if page_unique_tag_names:
                logger.info(
                    f"本页获取到的标签 ({len(page_unique_tag_names)} 个): {', '.join(list(page_unique_tag_names)[:50])}{'...' if len(page_unique_tag_names) > 50 else ''}"
                )

            if all_tags_to_upsert:
                count = storage.upsert_tags_batch(all_tags_to_upsert)
                logger.debug(f"成功更新 {count} 个标签条目。")

            current_count = len(illusts)
            total_illusts_processed += current_count
            offset += args.limit  # 使用固定步长

            logger.info(f"目前已处理 {total_illusts_processed} 个插画作品。")

            # 这里的逻辑是解决问题的关键：
            # 如果 offset 已经达到 5000 或者 next_url 为空，则认为需要切分日期
            # Pixiv App API 通常在 offset > 1000 或 5000 时强制停止并返回 next_url 为 null
            if not response.get("next_url") or offset >= 1000:
                if last_illust_date:
                    try:
                        # 尝试将最后一个作品的日期作为下一段的结束日期
                        # 日期格式示例: 2024-02-24T12:34:56+09:00
                        date_str = last_illust_date.split("T")[0]
                        dt = datetime.datetime.strptime(date_str, "%Y-%m-%d")
                        # 减去一天以继续向下搜索。
                        # 对于作品极多的标签，可能需要更精细的时间切分（如按小时），
                        # 但对于 800+作品的标签，按天切分足够了。
                        new_end_date = (dt - datetime.timedelta(days=1)).strftime(
                            "%Y-%m-%d"
                        )

                        if current_end_date == new_end_date:
                            # 避免死循环
                            logger.info("日期无法进一步切分，停止搜索。")
                            break

                        logger.info(
                            f"触发分页限制（当前 Offset: {offset}），正在切换时间切片至 {new_end_date} 之前..."
                        )
                        current_end_date = new_end_date
                        offset = 0  # 重置 offset 从新时间段的第一页开始
                        continue
                    except Exception as e:
                        logger.error(f"日期切分失败: {e}")
                        break
                else:
                    logger.info("已达到 API 返回的最后一页。")
                    break

            time.sleep(1)

    except KeyboardInterrupt:
        logger.info("\n用户中止操作。")
    except Exception as e:
        logger.error(f"搜索过程中发生错误: {e}", exc_info=True)
    finally:
        logger.info(
            f"搜索结束。已处理标签 '{args.tag}' 相关的共 {total_illusts_processed} 个插画。"
        )


if __name__ == "__main__":
    main()
