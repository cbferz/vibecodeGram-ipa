# Android-to-iOS feature map

Based on the current Android UI composables and `ApiClient.kt`, cross-checked against Go route registration and handlers.

| Android area | iOS implementation | Status / backend constraint |
|---|---|---|
| Authentication and session restore | `Features/Auth`, `Core/Storage` | Implemented; Keychain token storage |
| Main navigation | `AuthenticatedTabView` | Feed, vibees, chats, profile tabs |
| Feed | `Features/Feed` | Text/video posts, sorting, recommendations, likes, saves, hide, comments |
| Stories | `Features/Stories` | View, create image/MP4, delete, 5/12/24/48h expiration |
| Vibees | `Features/Vibees` | Vertical MP4 feed, pagination, likes/saves and upload |
| Chats | `Features/Messaging` | Direct/group conversations, history and send via REST |
| Search | `Features/Search` | User and post search |
| Public/own profile | `Features/Profile` | Stats, follow/unfollow, posts/videos/vibees, edit profile |
| Notifications | `Features/Notifications` | List and mark read |
| Comments | `Features/Comments` | List and create |
| Moderation | `Features/Feed`, `Features/Settings` | Report, block/unblock, hide/unhide |
| Sessions | `Features/Settings` | List and revoke, including current session |
| Badges | `Features/Settings` | View granted badges |
| AI | `Features/AI` | Model catalogue, chat and text tools when provider is configured |
| Appearance | `Features/Settings`, `Core/DesignSystem` | System/light/dark; additional Android customization remains |
| Device accounts | Planned | Account switching remains to be implemented |

## Wire-contract details

- Profile media kinds are exactly `posts`, `videos` and `vibees`.
- Short-video product label is **vibees** (lowercase).
- Reel upload: `POST /v1/reels/video`; regular video post: `POST /v1/posts/video`.
- Story duration values are exactly 5, 12, 24 and 48 hours.
- Story media limit is 15 MiB; MP4 post/reel upload limit is 50 MiB.
- Chat REST endpoints work, but the current WebSocket handler only acknowledges the connection and reads frames; it does not broadcast events.
- No post-image upload route or image media table was found. Story image upload is supported.
- Avatar and cover profile fields accept URLs; they do not upload local images.

## Android source inventory

The primary UI is concentrated in `app/src/main/java/com/vibecodegram/MainActivity.kt`; API DTOs and HTTP/multipart calls are in `ApiClient.kt`. Inspected screens include `AuthScreen`, `FeedScreen`, `ReelsScreen`, `StoriesStrip`, `CreateStoryDialog`, `StoryViewerDialog`, `SearchScreen`, `PublicProfileScreen`, `NotificationsScreen`, `ChatsScreen`, `NewChatDialog`, `ChatRoomDialog`, `ProfileScreen`, `SessionManagerCard`, `AppearanceEditor` and profile color editing.
