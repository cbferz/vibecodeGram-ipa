# Android-to-iOS feature map

This map is based on the current Android UI composables and its `ApiClient.kt`, cross-checked against Go route registration.

| Android area | Current Android implementation | iOS destination | Backend status |
|---|---|---|---|
| Authentication | `AuthScreen`, restore `/v1/me`, login/register/logout | `Features/Auth` | Supported |
| Main navigation | Feed, vibees, chats, profile; header search, notifications, appearance | App navigation shell | Supported as separate routes |
| Feed | `FeedScreen`, post cards, sorting/filter actions, create post | `Features/Feed` | Text and video posts supported |
| Stories | Strip, create dialog, viewer, view/delete, expiration selector | `Features/Stories` | Supported; multipart media upload |
| Vibees | Full-screen vertical video pager, pagination, mute/play, like/save, video composer | `Features/Vibees` | Reel endpoints supported |
| Chats | Conversations, new direct/group chat, message history and send | `Features/Messaging` | REST supported; WebSocket is handshake-only today |
| Search | User/post search and profile/chat entry points | `Features/Search` | Supported |
| Public profile | Profile stats and posts/videos/vibees tabs | `Features/Profile` | Supported |
| Own profile | Edit name, bio, avatar URL, cover URL, website, location | `Features/Profile` | Supported |
| Notifications | List and mark read | `Features/Notifications` | Supported |
| Comments | List/create comments | `Features/Comments` | Supported |
| Saved/hidden content | Save/unsave and hide/unhide posts | Feed/detail actions | Supported |
| Moderation | Block/unblock users, report posts, view reports | `Features/Moderation` | Supported |
| Sessions | List active sessions and revoke session | `Features/Settings` | Supported |
| Device accounts | Add/list/remove accounts for a stable device ID | `Features/Accounts` | Supported |
| Badges | View badges; staff grant/revoke controls where authorized | `Features/Badges` | Supported |
| AI | Chat, model catalogue, text tools | `Features/AI` | Supported when server AI provider is configured |
| Appearance | Six palettes, accent selection, glass intensity, compact mode | `Core/DesignSystem`, `Features/Settings` | Local-only preferences |
| Profile appearance | Profile hue, saturation, brightness and gradient | `Features/Profile` | Local-only preferences |

## Important semantic details

- Android's profile media filter values are exactly `posts`, `videos` and `vibees`. Keep these wire values unchanged.
- Android's short-video product label is **vibees** (lowercase).
- The backend reel upload endpoint is `POST /v1/reels/video`; normal video posts use `POST /v1/posts/video`.
- Story duration choices must remain exactly 5, 12, 24 and 48 hours.
- Do not treat the WebSocket `connected` handshake as evidence that server-side messages or notifications are pushed.
- Photo publishing is currently a backend gap. Profile avatar/cover fields accept URLs, but that is not a media upload service.

## Android UI inspection notes

The primary UI is currently concentrated in `app/src/main/java/com/vibecodegram/MainActivity.kt`; the API DTOs and HTTP/multipart calls are in `ApiClient.kt`. The screen inventory includes `AuthScreen`, `FeedScreen`, `ReelsScreen`, `StoriesStrip`, `CreateStoryDialog`, `StoryViewerDialog`, `SearchScreen`, `PublicProfileScreen`, `NotificationsScreen`, `ChatsScreen`, `NewChatDialog`, `ChatRoomDialog`, `ProfileScreen`, `SessionManagerCard`, `AppearanceEditor` and profile color editing.
