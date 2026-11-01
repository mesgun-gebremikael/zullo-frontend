# Photo upload rollout

This app requires the backend's authenticated `/me/photos` API and `OwnedPhotoStorage` migration. Deploy/configure that backend first; do not merge/release only this frontend and expect uploads to work against an older API.

Cloudinary credentials belong only in the backend's secret environment. Flutter no longer uses `zullo_upload` or calls Cloudinary's upload API directly. When backend photo configuration is unavailable, the user receives a readable message and their saved images remain unchanged.

The gallery picker reduces images to at most 1920×1920; the server enforces the 10 MiB limit and ownership. Each network retry uses the same operation ID. A delayed response from a logged-out account cannot add a photo to a later session. A selected/uploaded picture becomes part of the public profile only after a successful profile save. Cancelling/removing a draft does not delete an already-saved image; unused uploads expire on the server.

Follow `deploy/PHOTO_STORAGE.md` in zullo-backend for activation, the required unsigned-preset shutdown, historical image ownership review, monitoring and actual Cloudinary tests. Android/iOS image selection (including HEIC), saved removal and account-closure tests remain required. The owner's emulator tests are pending because of emulator problems.
