# How it works

1.  The app retrieves the device information and presents it 
    on the screen (This will help us approximate the size of the recording).
2.  The start button:
    -   The app records a short video (12 seconds) that helps us determine
        the length of the long video.
    -   The app will start recording long video automatically.
3.  The stop button:
    -   Stops recording.
    -   Try to save the video with workaround (It will take a few seconds). 
        If this operation works, the app will show a dialog with the action to exectue XFile.saveTo on the same file.
    -   If this video is long enough, XFile.saveTo will crash the app / throw an exception.
