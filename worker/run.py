import logging


def main():
    # Global config
    logging.basicConfig(
        # INFO is the sweet spot for production
        format='%(asctime)s:%(levelname)s:%(message)s', level=logging.INFO
    )

    # Spin up the logger for this module
    logger = logging.getLogger(__name__)

    # Tell the lifecycle story
    logger.info("Booting up the DocFLow Worker...")

    try:
        # Calls will go there
        logger.info("Fetching enviroment variables...")
        # load config()

        logger.info("Hooking up to the RDS database")
        # connect_db()

        logger.info(
            "listening to the SQS queue. Waiting for documents to drop...")
        # start_sqs_worker()

    except Exception as e:
        logger.error(f"Fatal error during worker startup: {e}")


if __name__ == "__main__":
    main()
