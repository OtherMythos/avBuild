extern "C"{
#include <libavcodec/avcodec.h>
#include <libavformat/avformat.h>
#include <libavutil/channel_layout.h>
#include <libavutil/error.h>
#include <libavutil/opt.h>
#include <libswresample/swresample.h>
#include <libswscale/swscale.h>
}

#include <algorithm>
#include <cmath>
#include <cstdint>
#include <iostream>
#include <memory>
#include <stdexcept>
#include <string>
#include <vector>

namespace{
    constexpr int kWidth = 320;
    constexpr int kHeight = 180;
    constexpr int kFps = 30;
    constexpr int kFrames = 60;
    constexpr int kSampleRate = 48000;
    constexpr int kSamples = 2 * kSampleRate;
    constexpr double kPi = 3.14159265358979323846;

    void require(bool condition, const std::string& message){
        if(!condition) throw std::runtime_error(message);
    }

    void check(int result, const char* operation){
        if(result >= 0) return;
        char error[AV_ERROR_MAX_STRING_SIZE];
        av_strerror(result, error, sizeof(error));
        throw std::runtime_error(std::string(operation) + ": " + error);
    }

    struct CodecDeleter{
        void operator()(AVCodecContext* value) const{ avcodec_free_context(&value); }
    };
    struct FrameDeleter{
        void operator()(AVFrame* value) const{ av_frame_free(&value); }
    };
    struct PacketDeleter{
        void operator()(AVPacket* value) const{ av_packet_free(&value); }
    };
    using Codec = std::unique_ptr<AVCodecContext, CodecDeleter>;
    using Frame = std::unique_ptr<AVFrame, FrameDeleter>;
    using Packet = std::unique_ptr<AVPacket, PacketDeleter>;

    struct Movie{
        AVFormatContext* context = nullptr;
        ~Movie(){
            if(context){
                if(context->pb) avio_closep(&context->pb);
                avformat_free_context(context);
            }
        }
    };

    void encode(AVFormatContext* movie, AVCodecContext* codec, AVStream* stream, AVFrame* frame){
        check(avcodec_send_frame(codec, frame), "send encoder frame");
        Packet packet(av_packet_alloc());
        while(true){
            int result = avcodec_receive_packet(codec, packet.get());
            if(result == AVERROR(EAGAIN) || result == AVERROR_EOF) break;
            check(result, "receive encoder packet");
            //OpenH264 leaves duration unset; MP4 otherwise trims the final image on decode.
            if(codec->codec_type == AVMEDIA_TYPE_VIDEO && packet->duration == 0) packet->duration = 1;
            av_packet_rescale_ts(packet.get(), codec->time_base, stream->time_base);
            packet->stream_index = stream->index;
            check(av_interleaved_write_frame(movie, packet.get()), "mux packet");
            av_packet_unref(packet.get());
        }
    }

    void writeMovie(const char* path, const char* videoEncoder){
        Movie movie;
        check(avformat_alloc_output_context2(&movie.context, nullptr, "mp4", path), "create MP4");
        const AVCodec* videoImpl = avcodec_find_encoder_by_name(videoEncoder);
        const AVCodec* audioImpl = avcodec_find_encoder_by_name("aac");
        require(videoImpl && audioImpl, "Required encoders absent");
        Codec video(avcodec_alloc_context3(videoImpl));
        Codec audio(avcodec_alloc_context3(audioImpl));
        video->width = kWidth;
        video->height = kHeight;
        video->pix_fmt = AV_PIX_FMT_YUV420P;
        video->time_base = AVRational{1, kFps};
        video->framerate = AVRational{kFps, 1};
        video->bit_rate = 2000000;
        video->gop_size = kFps;
        video->max_b_frames = 0;
        video->thread_count = 1;
        video->color_range = AVCOL_RANGE_MPEG;
        video->colorspace = AVCOL_SPC_BT709;
        video->color_primaries = AVCOL_PRI_BT709;
        video->color_trc = AVCOL_TRC_BT709;
        audio->sample_rate = kSampleRate;
        audio->sample_fmt = AV_SAMPLE_FMT_FLTP;
        audio->time_base = AVRational{1, kSampleRate};
        audio->bit_rate = 192000;
        av_channel_layout_default(&audio->ch_layout, 2);
        if(movie.context->oformat->flags & AVFMT_GLOBALHEADER){
            video->flags |= AV_CODEC_FLAG_GLOBAL_HEADER;
            audio->flags |= AV_CODEC_FLAG_GLOBAL_HEADER;
        }
        if(std::string(videoEncoder) == "h264_videotoolbox"){
            check(av_opt_set(video->priv_data, "allow_sw", "0", 0), "require hardware encoder");
        }
        check(avcodec_open2(video.get(), videoImpl, nullptr), "open video encoder");
        check(avcodec_open2(audio.get(), audioImpl, nullptr), "open AAC encoder");
        AVStream* videoStream = avformat_new_stream(movie.context, nullptr);
        AVStream* audioStream = avformat_new_stream(movie.context, nullptr);
        require(videoStream && audioStream, "Cannot allocate streams");
        videoStream->time_base = video->time_base;
        audioStream->time_base = audio->time_base;
        check(avcodec_parameters_from_context(videoStream->codecpar, video.get()), "copy video parameters");
        check(avcodec_parameters_from_context(audioStream->codecpar, audio.get()), "copy audio parameters");
        check(avio_open(&movie.context->pb, path, AVIO_FLAG_WRITE), "open output");
        AVDictionary* options = nullptr;
        av_dict_set(&options, "movflags", "+faststart", 0);
        int headerResult = avformat_write_header(movie.context, &options);
        av_dict_free(&options);
        check(headerResult, "write MP4 header");

        Frame image(av_frame_alloc());
        image->format = video->pix_fmt;
        image->width = kWidth;
        image->height = kHeight;
        check(av_frame_get_buffer(image.get(), 32), "allocate image");
        auto scaler = std::unique_ptr<SwsContext, decltype(&sws_freeContext)>(
            sws_getContext(kWidth, kHeight, AV_PIX_FMT_RGBA, kWidth, kHeight,
                           video->pix_fmt, SWS_BILINEAR, nullptr, nullptr, nullptr), sws_freeContext);
        require(scaler != nullptr, "Cannot create pixel converter");
        std::vector<uint8_t> rgba(kWidth * kHeight * 4);
        for(int frame = 0; frame < kFrames; ++frame){
            for(int y = 0; y < kHeight; ++y){
                for(int x = 0; x < kWidth; ++x){
                    const int offset = (y * kWidth + x) * 4;
                    rgba[offset] = uint8_t(x * 255 / kWidth);
                    rgba[offset + 1] = uint8_t(y * 255 / kHeight);
                    rgba[offset + 2] = uint8_t(frame * 4);
                    rgba[offset + 3] = 255;
                    if(x >= frame * 4 && x < frame * 4 + 32 && y < 32){
                        rgba[offset] = 255;
                        rgba[offset + 1] = 255;
                    }
                }
            }
            check(av_frame_make_writable(image.get()), "make image writable");
            const uint8_t* pixels[] = {rgba.data()};
            int stride[] = {kWidth * 4};
            require(sws_scale(scaler.get(), pixels, stride, 0, kHeight, image->data, image->linesize) == kHeight,
                    "Incomplete pixel conversion");
            image->pts = frame;
            encode(movie.context, video.get(), videoStream, image.get());
        }
        encode(movie.context, video.get(), videoStream, nullptr);

        AVChannelLayout stereo = AV_CHANNEL_LAYOUT_STEREO;
        SwrContext* rawResampler = nullptr;
        check(swr_alloc_set_opts2(&rawResampler, &stereo, audio->sample_fmt, kSampleRate,
                                 &stereo, AV_SAMPLE_FMT_FLT, 44100, 0, nullptr), "create resampler");
        auto resampler = std::unique_ptr<SwrContext, void(*)(SwrContext*)>(rawResampler,
            [](SwrContext* value){ swr_free(&value); });
        check(swr_init(resampler.get()), "init resampler");
        std::vector<float> input(44100 * 2 * 2);
        for(int i = 0; i < 44100 * 2; ++i){
            input[i * 2] = float(0.25 * std::sin(2 * kPi * 440 * i / 44100));
            input[i * 2 + 1] = float(0.25 * std::sin(2 * kPi * 660 * i / 44100));
        }
        Frame sound(av_frame_alloc());
        sound->format = audio->sample_fmt;
        sound->sample_rate = kSampleRate;
        check(av_channel_layout_copy(&sound->ch_layout, &stereo), "copy channel layout");
        sound->nb_samples = kSamples + 256;
        check(av_frame_get_buffer(sound.get(), 0), "allocate resampled audio");
        const uint8_t* inputPlanes[] = {reinterpret_cast<const uint8_t*>(input.data())};
        int converted = swr_convert(resampler.get(), sound->data, sound->nb_samples, inputPlanes, 44100 * 2);
        check(converted, "resample audio");
        uint8_t* tail[] = {sound->data[0] + converted * sizeof(float), sound->data[1] + converted * sizeof(float)};
        int flushed = swr_convert(resampler.get(), tail, sound->nb_samples - converted, nullptr, 0);
        check(flushed, "flush resampler");
        require(converted + flushed == kSamples, "Incorrect resampled sample count");
        for(int offset = 0; offset < kSamples; offset += audio->frame_size){
            Frame block(av_frame_alloc());
            block->format = audio->sample_fmt;
            block->sample_rate = kSampleRate;
            check(av_channel_layout_copy(&block->ch_layout, &stereo), "copy block channels");
            block->nb_samples = std::min(audio->frame_size, kSamples - offset);
            block->pts = offset;
            check(av_frame_get_buffer(block.get(), 0), "allocate audio block");
            for(int channel = 0; channel < 2; ++channel){
                std::copy_n(reinterpret_cast<float*>(sound->data[channel]) + offset, block->nb_samples,
                            reinterpret_cast<float*>(block->data[channel]));
            }
            encode(movie.context, audio.get(), audioStream, block.get());
        }
        encode(movie.context, audio.get(), audioStream, nullptr);
        check(av_write_trailer(movie.context), "finalise MP4");
    }

    void verifyMovie(const char* path){
        AVFormatContext* rawInput = nullptr;
        check(avformat_open_input(&rawInput, path, nullptr, nullptr), "reopen MP4");
        auto input = std::unique_ptr<AVFormatContext, void(*)(AVFormatContext*)>(rawInput,
            [](AVFormatContext* value){ avformat_close_input(&value); });
        check(avformat_find_stream_info(input.get(), nullptr), "read stream information");
        require(input->nb_streams == 2, "Expected two streams");
        require(std::abs(double(input->duration) / AV_TIME_BASE - 2.0) < 0.03, "Incorrect movie duration");
        Codec decoders[2];
        int videoIndex = -1;
        int audioIndex = -1;
        for(unsigned int i = 0; i < 2; ++i){
            auto* parameters = input->streams[i]->codecpar;
            const AVCodec* codec = avcodec_find_decoder(parameters->codec_id);
            require(codec != nullptr, "Decoder absent");
            decoders[i].reset(avcodec_alloc_context3(codec));
            check(avcodec_parameters_to_context(decoders[i].get(), parameters), "copy decoder parameters");
            decoders[i]->thread_count = 1;
            check(avcodec_open2(decoders[i].get(), codec, nullptr), "open decoder");
            if(parameters->codec_type == AVMEDIA_TYPE_VIDEO) videoIndex = int(i);
            if(parameters->codec_type == AVMEDIA_TYPE_AUDIO) audioIndex = int(i);
        }
        require(videoIndex >= 0 && audioIndex >= 0, "Expected video and audio");
        int frames = 0;
        int samples = 0;
        double energy[2] = {};
        int crossings[2] = {};
        float previous[2] = {};
        int firstBlue = 0;
        int lastBlue = 0;
        int64_t lastDts[2] = {AV_NOPTS_VALUE, AV_NOPTS_VALUE};
        Frame decoded(av_frame_alloc());
        auto receive = [&](int stream){
            while(true){
                int result = avcodec_receive_frame(decoders[stream].get(), decoded.get());
                if(result == AVERROR(EAGAIN) || result == AVERROR_EOF) break;
                check(result, "decode frame");
                double time = decoded->best_effort_timestamp * av_q2d(input->streams[stream]->time_base);
                if(stream == videoIndex){
                    require(decoded->width == kWidth && decoded->height == kHeight, "Incorrect video dimensions");
                    require(std::abs(time - double(frames) / kFps) < 0.0001, "Incorrect video timestamp spacing");
                    auto scaler = std::unique_ptr<SwsContext, decltype(&sws_freeContext)>(
                        sws_getContext(kWidth, kHeight, AVPixelFormat(decoded->format), kWidth, kHeight,
                                       AV_PIX_FMT_RGBA, SWS_BILINEAR, nullptr, nullptr, nullptr), sws_freeContext);
                    require(scaler != nullptr, "Cannot convert decoded image");
                    std::vector<uint8_t> rgba(kWidth * kHeight * 4);
                    uint8_t* pixels[] = {rgba.data()};
                    int stride[] = {kWidth * 4};
                    require(sws_scale(scaler.get(), decoded->data, decoded->linesize, 0, kHeight, pixels, stride) == kHeight,
                            "Cannot convert decoded pixels");
                    lastBlue = rgba[(kWidth * kHeight / 2) * 4 + 2];
                    if(frames == 0) firstBlue = lastBlue;
                    ++frames;
                }else{
                    require(decoded->format == AV_SAMPLE_FMT_FLTP && decoded->ch_layout.nb_channels == 2,
                            "Unexpected decoded audio format");
                    require(std::abs(time - double(samples) / kSampleRate) < 0.0001, "Incorrect audio timestamp spacing");
                    for(int channel = 0; channel < 2; ++channel){
                        const float* data = reinterpret_cast<const float*>(decoded->data[channel]);
                        for(int i = 0; i < decoded->nb_samples; ++i){
                            energy[channel] += double(data[i]) * data[i];
                            if(previous[channel] <= 0 && data[i] > 0) ++crossings[channel];
                            previous[channel] = data[i];
                        }
                    }
                    samples += decoded->nb_samples;
                }
                av_frame_unref(decoded.get());
            }
        };
        Packet packet(av_packet_alloc());
        int result;
        while((result = av_read_frame(input.get(), packet.get())) >= 0){
            int stream = packet->stream_index;
            require(stream < 2, "Unexpected packet stream");
            require(packet->dts != AV_NOPTS_VALUE, "Missing packet timestamp");
            require(lastDts[stream] == AV_NOPTS_VALUE || packet->dts > lastDts[stream], "Non-increasing packet timestamps");
            lastDts[stream] = packet->dts;
            check(avcodec_send_packet(decoders[stream].get(), packet.get()), "send decoder packet");
            receive(stream);
            av_packet_unref(packet.get());
        }
        require(result == AVERROR_EOF, "Error reading movie");
        for(int stream = 0; stream < 2; ++stream){
            check(avcodec_send_packet(decoders[stream].get(), nullptr), "flush decoder");
            receive(stream);
        }
        require(frames == kFrames, "Incorrect decoded frame count");
        require(lastBlue - firstBlue > 150, "Decoded image did not change as expected");
        //AAC pads the final frame; the MP4 stream duration records the unpadded length.
        require(samples >= kSamples && samples < kSamples + 1024, "Incorrect decoded audio sample count");
        auto* audioStream = input->streams[audioIndex];
        require(std::abs(audioStream->duration * av_q2d(audioStream->time_base) - 2.0) < 0.0001,
                "Incorrect audio stream duration");
        for(int channel = 0; channel < 2; ++channel){
            double rms = std::sqrt(energy[channel] / samples);
            require(rms > 0.15 && rms < 0.20, "Incorrect decoded audio amplitude");
            require(std::abs(crossings[channel] - (channel == 0 ? 880 : 1320)) < 25, "Incorrect tone frequency");
        }
        std::cout << "Verified " << frames << " frames, " << samples
                  << " decoded stereo samples, 2.000 seconds, moving image and 440/660 Hz audio.\n";
    }
}

int main(int argc, char** argv){
    try{
        require(argc == 2 || argc == 3, "Usage: avFFmpegTest output.mp4 [video_encoder]");
        require(std::string(avcodec_license()) == "LGPL version 2.1 or later", "Unexpected codec licence");
        writeMovie(argv[1], argc == 3 ? argv[2] : "libopenh264");
        verifyMovie(argv[1]);
        return 0;
    }catch(const std::exception& error){
        std::cerr << "FFmpeg verification failed: " << error.what() << '\n';
        return 1;
    }
}
