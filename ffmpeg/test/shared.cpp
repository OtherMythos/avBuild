extern "C"{
#include <libavcodec/avcodec.h>
}

extern "C" const AVCodec* avFFmpegH264Decoder(){
    return avcodec_find_decoder(AV_CODEC_ID_H264);
}
