Chops video into images

It downloads a file from s3 and uploads it back to s3 after chopping the images locally.
It saves the chopped image in the current working directory locally.

The FRAMESPERSEC environment variable can be used to define the number of image shots you want per second.

Install ffmpeg into the console before running the code.
Following command installs ffmpeg:
```brew install ffmpeg --with-fdk-aac --with-ffplay --with-freetype --with-frei0r --with-libass --with-libvo-aacenc --with-libvorbis --with-libvpx --with-opencore-amr --with-openjpeg --with-opus --with-rtmpdump --with-schroedinger --with-speex --with-theora --with-tools```

Finally run the code using: `python videotoimage.py`
