import os
import asyncio
from datetime import datetime, timedelta, timezone
from dotenv import load_dotenv
from telethon import TelegramClient
from telethon.tl.types import InputMessagesFilterVideo


async def cleanup_old_videos():
    """Delete user's own video messages older than 2 weeks without reactions"""
    client = TelegramClient(
        session=os.getenv("SESSION_NAME", "default_session"),
        api_id=int(os.getenv("API_ID")),
        api_hash=os.getenv("API_HASH")
    )

    try:
        await client.start(phone=os.getenv("PHONE"))
        
        two_weeks_ago = datetime.now(timezone.utc) - timedelta(days=14)
    
        entity = await client.get_entity(int(os.getenv("CHAT_ID")))

        async for message in client.iter_messages(
            entity=entity,
            filter=InputMessagesFilterVideo,
            search='Видео со звонка',
            wait_time=2
        ):
            try:
                if (message.video and 
                    not message.reactions and
                    message.date < two_weeks_ago):

                    await message.delete()
                    print(f"✅ Deleted message {message.id} from {message.date}")
                    
            except Exception as e:
                print(f"❌ Error processing message {message.id}: {str(e)}")
    finally:
        await client.disconnect()



if __name__ == "__main__":
    load_dotenv()
    asyncio.run(cleanup_old_videos())
