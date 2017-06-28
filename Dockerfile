from turnerlabs/video-slicer-base

ADD . /opt/app/

ENTRYPOINT ["python", "/opt/app/video_to_image.py"]
