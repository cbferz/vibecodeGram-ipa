# Backend API compatibility audit

Source: `cbferz/vibecodeGram`, branch `main`, audited 2026-11-27. The Android client configures `https://api.vibecodegram.tendercheck.pro` as its API origin.

All routes below are under `/v1` unless marked otherwise. Authenticated routes require a JWT bearer token.

## Authentication and sessions

| Method | Path | Notes |
|---|---|---|
| POST | `/auth/register` | `username`, `password`, optional `display_name`; username 3–32 lowercase letters/digits/underscore; password 10–72 bytes |
| POST | `/auth/login` | `username`, `password` |
| GET | `/me` | Current user |
| POST | `/auth/logout` | Revokes current server session |
| GET | `/sessions` | Active sessions |
| DELETE | `/sessions/{sessionID}` | Revoke a session |

Tokens are JWT HS256 and reference a server-side session. Server sessions expire after 30 days. A token may be rejected before JWT expiry if its session is revoked.

## Posts and video

| Method | Path | Notes |
|---|---|---|
| GET | `/posts?sort=...` | Feed; inspect server sort/pagination implementation before relying on undocumented query parameters |
| POST | `/posts` | JSON text post: `body`, `tag` |
| POST | `/posts/video` | Multipart `body`, `tag`, `video`; MP4, max 50 MiB |
| GET | `/posts/{id}/video` | Authenticated MP4 stream; byte ranges supported |
| POST | `/posts/{id}/like` | Toggle like |
| PUT | `/posts/{id}/save` | Save post |
| DELETE | `/posts/{id}/save` | Unsave post |
| POST | `/posts/{id}/hide` | Hide post |
| DELETE | `/posts/{id}/hide` | Unhide post |
| GET | `/reels?limit=&offset=` | Video/reel feed |
| POST | `/reels/video` | Multipart video reel creation |

**Image-post gap:** no image upload route or image media table was found in the current backend route registration/migrations. The iOS client must not invent a photo-post endpoint. Image publishing requires a separately reviewed, backward-compatible backend feature before it can be implemented end-to-end.

## Stories

| Method | Path | Notes |
|---|---|---|
| GET | `/stories` | Active stories |
| POST | `/stories` | Multipart `caption`, `duration_hours`, `media`; maximum media size 15 MiB |
| GET | `/stories/{id}/media` | Authenticated story media |
| POST | `/stories/{id}/view` | Mark viewed |
| DELETE | `/stories/{id}` | Delete own story |

The server accepts expiration durations 5, 12, 24 or 48 hours.

## Profiles and social graph

| Method | Path |
|---|---|
| GET | `/users/search?q=` |
| GET | `/users/{id}` |
| GET | `/users/{id}/posts?kind=posts|videos|vibees` |
| PUT | `/me/profile` |
| POST | `/users/{id}/follow` |
| DELETE | `/users/{id}/follow` |
| GET | `/users/{id}/followers` |
| GET | `/users/{id}/following` |
| GET | `/posts/search?q=` |
| GET | `/recommendations` |

Profile JSON includes username, display name, bio, avatar/cover URLs, website, location, follower/following/post/like counts, followed and is_me flags.

## Comments and notifications

| Method | Path |
|---|---|
| GET | `/posts/{id}/comments` |
| POST | `/posts/{id}/comments` |
| GET | `/notifications` |
| POST | `/notifications/read` |

## Messaging

| Method | Path |
|---|---|
| GET | `/conversations` |
| POST | `/conversations` |
| GET | `/conversations/{id}/messages?limit=&before=` |
| POST | `/conversations/{id}/messages` |

The backend scopes conversations and messages to membership of the authenticated user. Conversation creation accepts `kind` (`direct` or `group`), optional `title`, and `member_ids`.

The authenticated WebSocket is `GET /v1/ws?token=JWT`. The current handler validates the token/session, upgrades the connection and sends a `connected` JSON frame; it then only reads until disconnect. It is not a server-push event stream in the current implementation.

## Moderation

| Method | Path |
|---|---|
| POST | `/users/{id}/block` |
| DELETE | `/users/{id}/block` |
| GET | `/me/blocked` |
| POST | `/posts/{id}/report` |
| GET | `/me/reports?limit=` |

## Accounts and badges

| Method | Path |
|---|---|
| GET | `/me/badges` |
| GET | `/devices/accounts?device_id=` |
| POST | `/devices/accounts` |
| DELETE | `/devices/accounts/{accountID}?device_id=` |
| POST | `/admin/users/{id}/badges` |
| DELETE | `/admin/users/{id}/badges/{badge}` |

The internal subscription webhook is `PUT /internal/subscriptions/{id}` and requires `X-Subscription-Secret`. This secret is server-only and must never be embedded in the app.

## AI

| Method | Path |
|---|---|
| GET | `/ai/models` |
| POST | `/ai/chat` |
| POST | `/ai/tools/{tool}` |

AI routes require normal bearer authentication. Provider credentials remain on the backend.

## Error and transport rules

- JSON API errors use an `error` string.
- Treat HTTP 401 as an expired/revoked session: clear the local Keychain token and present authentication.
- Do not retry non-idempotent writes blindly after an ambiguous transport failure.
- Media routes are authenticated; attach bearer authorization when requesting protected streams.
- Keep request and response models endpoint-specific. Do not infer undocumented fields from UI labels.
