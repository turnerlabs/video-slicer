import botocore
import subprocess as sp
import os
import boto3
import datetime

#No. of frames per second
FRAMES = int(os.environ.get('FRAMESPERSEC'))

def convertVideoToImage(srcKey, srcBucket):
    s3 = boto3.resource('s3')
    localFilename = '/tmp/{}'.format(os.path.basename(srcKey))
    #Download video to local
    try:
        s3.Bucket(srcBucket).download_file(srcKey, localFilename)
    except botocore.exceptions.ClientError as e:
        if e.response['Error']['Code'] == "404":
            print("The object does not exist.")
        else:
            raise
    #Chop video into images
    cmd='ffmpeg -i '+str(localFilename)+' -r '+str(FRAMES)+' img_%04d.jpg'
    sp.call(cmd,shell=True)

    #Upload file to s3
    for imgFile in os.listdir("./"):
        if imgFile.find("img") != -1:
            with open(imgFile, "rb") as imageFile:
                f = imageFile.read()
                imgByteArr = bytearray(f)
                destination = 'video-image/'+str(datetime.datetime.now())+str(imgFile)
                object = s3.Bucket(srcBucket).put_object(Body = imgByteArr, Key = destination)


if __name__ == '__main__':
    #bucket in which the file can be downloaded and uploaded into
    srcBucket = str(os.environ.get('LOCAL_BUCKET'))
    #File to be downloaded from s3
    srcKey = str(os.environ.get('FILE'))
    desBucket = str()
    convertVideoToImage(srcKey,srcBucket)
