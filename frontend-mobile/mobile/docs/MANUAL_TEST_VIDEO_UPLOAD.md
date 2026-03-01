# Manual Testing Guide: Video Upload with Blossom

## Test Objective
Verify that video upload to Blossom server works correctly with PUT method and that Nostr events are published successfully.

## Prerequisites
- Flutter app running on Chrome: `./run_dev.sh chrome debug`
- Access to Chrome DevTools Console for logs
- Authenticated user (signed in with Nostr keys)

## Test Steps

### 1. Start the App
```bash
cd mobile
./run_dev.sh chrome debug
```

Wait for app to load at `http://localhost:53424/`

### 2. Navigate to Camera Screen
1. Click the camera/record button in the app UI
2. Verify camera preview appears

### 3. Record a Test Video
1. Click record button to start recording
2. Record for 3-5 seconds
3. Click stop button
4. Verify you see the video metadata screen

### 4. Add Metadata and Publish
1. Enter a test title (e.g., "test upload")
2. Click "Publish" button
3. **Watch the console logs carefully**

## Expected Log Output (Success)

```
[VIDEO] 📹 Publish button pressed
[VIDEO] 📹 Finishing recording and concatenating segments
[SYSTEM] 📱 finishRecording: hasSegments=true, segments count=1
[VIDEO] 📹 Recording finished, result: /path/to/video.mov
[VIDEO] 📝 Starting upload to Blossom server...
[VIDEO] 🚀 === STARTING UPLOAD ===
[VIDEO] ✅ User is authenticated, can create signed events
[VIDEO] Uploading using Blossom spec (PUT with raw bytes)
[VIDEO] File hash: <sha256-hash>, size: <bytes> bytes
[VIDEO] Sending PUT request with raw video bytes
[VIDEO]   URL: https://cf-stream-service-prod.protestnet.workers.dev/upload
[VIDEO]   File size: <bytes> bytes
[VIDEO] Blossom server response: 200  # ✅ Success!
[VIDEO] Response data: {url: https://cdn.divine.video/<hash>.mp4, ...}
[VIDEO] ✅ Blossom upload successful
[VIDEO]   URL: https://cdn.divine.video/<hash>.mp4
[VIDEO]   Video ID (hash): <sha256-hash>
[VIDEO] 📝 Publishing Nostr event...
[VIDEO] ✅ Nostr event published successfully
```

## Expected Log Output (Failure)

### If Upload Fails (Old Bug - Should NOT happen now):
```
[VIDEO] Blossom server response: 404
[VIDEO] Response data: {error: not_found}
[VIDEO] ❌ Upload failed: 404 - {error: not_found}
[VIDEO] Cannot publish upload - missing videoId or cdnUrl
```

### If Not Authenticated:
```
[VIDEO] ❌ User not authenticated - cannot sign Blossom requests
[VIDEO] 🚫 Upload failed: Not authenticated
```

## Success Criteria

✅ **PASS** if all of these are true:
1. Upload completes with HTTP 200 or 201 response
2. Response includes `url` field with CDN URL
3. Nostr event is published successfully
4. No error messages in logs
5. Video appears in feed after publishing

❌ **FAIL** if any of these occur:
1. HTTP 404 or 400 error
2. Missing `url` in response
3. "Cannot publish upload - missing videoId or cdnUrl" error
4. Upload times out or crashes

## Troubleshooting

### Problem: 404 Error
**Cause**: Backend not deployed or routing issue
**Action**: Contact backend team, verify server is running

### Problem: 401 Authentication Error
**Cause**: Auth event signature invalid
**Action**: Check that user is signed in, verify key storage working

### Problem: Upload Never Completes
**Cause**: Network timeout or large file
**Action**: Check network connection, try smaller video

### Problem: "Cannot publish upload" Error
**Cause**: Upload succeeded but response malformed
**Action**: Check server response format, verify `url` field exists

## Quick Curl Test (Optional)

Test the endpoint directly without the app:

```bash
# 1. Create a small test file
dd if=/dev/zero of=test.mp4 bs=1024 count=1

# 2. Calculate hash
FILE_HASH=$(shasum -a 256 test.mp4 | cut -d' ' -f1)
echo "File hash: $FILE_HASH"

# 3. Create minimal auth event (pseudo-code)
# In real test, you'd need to:
# - Generate proper Nostr event
# - Sign it with private key
# - Base64 encode the JSON

# 4. Upload
curl -X PUT \
  https://cf-stream-service-prod.protestnet.workers.dev/upload \
  -H "Content-Type: video/mp4" \
  -H "Content-Length: $(wc -c < test.mp4)" \
  -H "Authorization: Nostr <base64-encoded-event>" \
  --data-binary @test.mp4 \
  -v
```

Expected response:
```json
{
  "url": "https://cdn.divine.video/<hash>.mp4",
  "sha256": "<hash>",
  "size": 1024,
  "uploaded": 1234567890
}
```

## Related Files

- Implementation: `lib/services/blossom_upload_service.dart`
- Upload Manager: `lib/services/upload_manager.dart`
- Camera Screen: `lib/screens/pure/universal_camera_screen_pure.dart`
- Metadata Screen: `lib/screens/pure/video_metadata_screen_pure.dart`

## Test Results

**Date**: _________________
**Tester**: _________________
**Result**: ☐ PASS  ☐ FAIL
**Notes**:

---

**Server Response Code**: _________________
**CDN URL Received**: ☐ Yes  ☐ No
**Nostr Event Published**: ☐ Yes  ☐ No
**Video Appeared in Feed**: ☐ Yes  ☐ No

---

## Additional Notes

