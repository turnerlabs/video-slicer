from __future__ import division
import botocore
import subprocess as sp
import os
import boto3
import datetime
import sys
import zipfile
import math
import time


#No. of frames per second
FRAMES = float(os.environ.get('FRAMESPERSEC','1'))
TMP_DIR = "/tmp/output/"
TMP_RENAME = TMP_DIR + "renamed/"

if not os.path.exists(TMP_DIR):
    os.makedirs(TMP_DIR)

if not os.path.exists(TMP_RENAME):
    os.makedirs(TMP_RENAME)

def timing(f):
    def wrap(*args):
        time1 = time.time()
        ret = f(*args)
        time2 = time.time()
        print '++++++++++++++++++++ TIMING ++++++++++++++++++++++++++++++++++++'
        print ''
        print '%s function took %0.3f m' % (f.func_name, ((time2-time1)/60))
        print ''
        print '++++++++++++++++++++ TIMING ++++++++++++++++++++++++++++++++++++'
        return ret
    return wrap

@timing
def getLength(video):
    val = sp.check_output('ffprobe -i ' + str(video)+ ' -show_entries format=duration -v quiet -of csv="p=0"',stdin=None, stderr=None, shell=True, universal_newlines=False)
    return val

@timing
def convertVideoToImage(srcKey, srcBucket):
    s3 = boto3.resource('s3')
    localFilename = '/tmp/{}'.format(os.path.basename(srcKey))

    # Download video to local
    try:
        s3.Bucket(srcBucket).download_file(srcKey, localFilename)
    except botocore.exceptions.ClientError as e:
        if e.response['Error']['Code'] == "404":
            print("The object does not exist.")
            sys.exit()
        else:
            raise
    # Chop video into images(-i is the input file name, -r is the number of frames per sec, img_%04d.jpg is the o/p format)
    try:
        #Get length of the video
        vidLength = float(getLength(localFilename))
        print vidLength
        imagesNo = vidLength*FRAMES
        imagesNo = math.ceil(imagesNo)
        imagesNo = int(imagesNo)
        print imagesNo
        #cmd='ffmpeg -i ' + str(localFilename)+ ' -r ' + str(FRAMES) + ' ' + TMP_DIR + 'img_%04d.jpg'
        cmd = 'ffmpeg -i ' + str(localFilename) + ' -ss 00:00:0.0 -vf fps=' +str(FRAMES)+ ' -vframes ' + str(imagesNo) + ' ' + TMP_DIR + 'img_%04d.jpg'
        print cmd
        sp.call(cmd,shell=True)
    except Exception as e:
        print("Error calling ffmpeg:", e)

    # Upload file to s3
    tmpKey = srcKey.rsplit(".",1)
    # Removing the video extention
    destKey = tmpKey[0]

    n = 1
    with zipfile.ZipFile('images.zip', 'w') as myzip:
        for imgFile in sorted(os.listdir(TMP_DIR)):
            if imgFile.find("img") != -1:
                timestamp = (1/FRAMES)*(n-1)
                strtimestamp = str(round(timestamp,2))
                filename = strtimestamp+'_'+str(imgFile)
                n = n + 1
                os.rename(TMP_DIR + imgFile, TMP_RENAME + filename)
                myzip.write(TMP_RENAME + filename)

    s3.Bucket(srcBucket).put_object(Body=open("./images.zip", 'rb'), Key=destKey + ".zip")


if __name__ == '__main__':
    #bucket in which the file can be downloaded and uploaded into
    srcBucket = str(os.environ.get('BUCKET'))
    #File to be downloaded from s3
    srcKey = str(os.environ.get('FILE'))
    convertVideoToImage(srcKey,srcBucket)
