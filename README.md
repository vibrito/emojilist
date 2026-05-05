# Emoji List

Emoji List is a SwiftUI iOS app built for the Bliss Recruitment iOS challenge. The app consumes GitHub APIs, persists selected data with Core Data, and demonstrates cached emoji/avatar browsing plus paginated repository loading.

## Features

- Loads GitHub emojis from the API and stores them locally with Core Data.
- Avoids refetching emojis when cached data already exists.
- Shows a random cached emoji from the stored list.
- Caches downloaded emoji images in Core Data.
- Displays all stored emojis in a grid.
- Removes tapped emojis only from the current in-memory grid list.
- Supports pull-to-refresh on the emoji grid to restore the full cached list.
- Searches GitHub users by username and stores avatar data locally.
- Uses cached avatar data when the searched user already exists in the database.
- Displays cached avatars in a grid.
- Deletes tapped avatars from Core Data.
- Lists Apple's GitHub repositories with pagination, fetching 10 repositories per request.

## Screens

- **Home**: Main actions for emoji list, random emoji, avatar list, Apple repos, and avatar search.
- **Emoji List**: Grid of cached emojis with temporary in-memory deletion and pull-to-refresh reset.
- **Avatar List**: Grid of stored GitHub avatars with permanent database deletion.
- **Apple Repos**: Paginated list of Apple repositories from GitHub.

## API Endpoints

```text
GET https://api.github.com/emojis
GET https://api.github.com/users/{username}
GET https://api.github.com/orgs/apple/repos?per_page=10&page={page}
```

## Persistence

The app uses Core Data with two entities:

- `EmojiItem`: stores the emoji name, image URL, and cached image data.
- `UserAvatar`: stores the GitHub login, GitHub user id, avatar URL, and cached avatar image data.

Emoji grid deletions only affect the current in-memory list. Avatar deletions remove the item from Core Data.

## Requirements

- Xcode
- iOS 17 or newer recommended
- SwiftUI
- Core Data

## Running the App

1. Open `Emoji List.xcodeproj` in Xcode.
2. Select an iOS simulator or device.
3. Build and run the `Emoji List` scheme.

From the terminal, the project can also be checked with:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -scheme "Emoji List" -destination "generic/platform=iOS" -derivedDataPath /private/tmp/emoji-list-derived-data CODE_SIGNING_ALLOWED=NO build
```

## Notes

GitHub API requests are rate-limited, so the app prefers cached data when possible. Emoji metadata is fetched only when the local cache is empty, emoji images are cached after the first download, and avatar searches use cached avatar data on repeated searches.
