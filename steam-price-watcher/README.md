# Steam Price Watcher

Monitor Steam game prices and get notified when they reach your target price.

## Features

- 🎮 **Price Monitoring**: Automatically check Steam game prices at configurable intervals
- 🎯 **Target Prices**: Set your desired price for each game
- 🔔 **Desktop Notifications**: Get notified via notify-send when games reach your target price
- 📊 **Visual Indicator**: Bar widget shows a notification dot when games are at target price
- 💰 **Price Comparison**: See current price vs. target price with discount percentages
- ⚙️ **Easy Configuration**: Search games by Steam App ID and add them to your watchlist
- 🔄 **Automatic Updates**: Prices are checked automatically based on your interval setting

## How to Use

### Adding Games to Watchlist

1. Open the plugin settings
2. Find the Steam App ID of the game you want to monitor
   - You can find this in the game's Steam page URL
   - Example: `https://store.steampowered.com/app/730/` → App ID is `730` (Counter-Strike 2)
3. Enter the App ID in the search field and click "Search"
4. Click "Add" on the search result
5. Set your target price (the plugin suggests 20% below current price)
6. Click "Add to Watchlist"

### Finding Steam App IDs

The Steam App ID is the number in the game's URL on the Steam store:

- **Counter-Strike 2**: `730`
- **Dota 2**: `570`  
- **GTA V**: `271590`
- **Red Dead Redemption 2**: `1174180`
- **Cyberpunk 2077**: `1091500`

You can find it by:
1. Going to the game's page on Steam
2. Looking at the URL: `https://store.steampowered.com/app/{APP_ID}/`
3. The number after `/app/` is the App ID

### Monitoring Prices

Once games are added to your watchlist:

- The widget will check prices automatically at your configured interval (default: 30 minutes)
- When a game reaches or goes below your target price:
  - A notification dot appears on the bar widget
  - You receive a desktop notification
  - The game is highlighted in the panel
- Click the widget to see all games and their current prices

### Managing Your Watchlist

In the panel (click the widget):

- View all monitored games with current and target prices
- See which games have reached target price (🎯 indicator)
- Edit target prices by clicking the edit icon
- Remove games from watchlist
- Refresh prices manually with the refresh button

### Settings

- **Check Interval**: How often to check prices (15-1440 minutes)
  - Default: 30 minutes
  - ⚠️ Very short intervals may result in many API requests
- **Watchlist**: Add or remove games from monitoring

## Technical Details

- **API**: Uses Steam Store API (`store.steampowered.com/api/appdetails`)
- **Currency**: Prices are fetched in BRL (Brazilian Real)
- **Data Storage**: Settings are stored in Noctalia's plugin configuration
- **Notifications**: Uses notify-send for desktop notifications

## Requirements

- Noctalia Shell v3.6.0 or higher
- Internet connection for API access
- `curl` command-line tool (for API requests)
- `notify-send` (for desktop notifications)

## Supported Languages

- Portuguese (pt)
- English (en)
- Spanish (es)
- French (fr)
- German (de)
- Italian (it)
- Japanese (ja)
- Dutch (nl)
- Russian (ru)
- Turkish (tr)
- Ukrainian (uk-UA)
- Chinese Simplified (zh-CN)

## Changelog

### Version 1.0.0
- Initial release
- Steam API integration
- Price monitoring with configurable intervals
- Target price alerts
- Desktop notifications
- Multi-language support

## Author

Noctalia Community

## License

This plugin follows the same license as Noctalia Shell.

## Tips

- Set realistic target prices (20-30% below current price is usually good)
- Don't set check intervals too short (<30 minutes) to avoid excessive API requests
- Games that are free or don't have pricing information cannot be added
- Notifications are sent only once per game until you update the target price
- The plugin remembers which games have been notified to avoid spam

## Troubleshooting

**Problem**: No prices showing  
**Solution**: Check your internet connection and verify the App ID is correct

**Problem**: Notifications not appearing  
**Solution**: Make sure notify-send is installed and working on your system

**Problem**: "No games found" when searching  
**Solution**: Verify the App ID is correct and the game exists on Steam

**Problem**: Prices not updating  
**Solution**: Click the refresh button in the panel or wait for the next automatic check

## Future Enhancements

Potential features for future versions:
- Support for multiple currencies
- Price history tracking
- Historical low price information
- Steam sale event notifications
- Wishlist import from Steam
- Email notifications option
