package org.mytvstream.frontend.flashwebsocket;

import java.io.IOException;

import org.json.simple.JSONObject;
import org.mytvstream.backend.Backend;
import org.mytvstream.backend.BackendException;
import org.mytvstream.backend.BackendListener;
import org.mytvstream.backend.Channel;
import org.mytvstream.configuration.Configuration;
import org.mytvstream.converter.Converter;
import org.mytvstream.converter.ConverterCodecEnum;
import org.mytvstream.converter.ConverterException;
import org.mytvstream.converter.ConverterFactory;
import org.mytvstream.converter.ConverterFormatEnum;
import org.mytvstream.converter.WebMConverter;
import org.mytvstream.converter.XugglerConverter;
import org.mytvstream.main.Main;
import org.slf4j.LoggerFactory;
import org.slf4j.Logger;

public class StartChannelMessageHandler extends MessageHandler {

	private Logger logger = LoggerFactory.getLogger(StartChannelMessageHandler.class);
	
	private static int CONVERTER_WAIT_TIMEOUT = 2000;
	
	protected Converter converter = new XugglerConverter();
			
	@Override
	protected boolean doHandle(JSONObject object) {
		// TODO Auto-generated method stub
		
		String action = (String)object.get("action");		
		
		if (action.equals("CHANNELSTART")) {
			
			logger.debug("Got CHANNELSTART message");
			
			String format = (String)object.get("format");
			long backendNr = (Long)object.get("backend");
			long bouquetNr = (Long)object.get("bouquet");
			long channelNr = (Long)object.get("channel");					
			String rtmp_url = (String)object.get("rtmpurl");
			String rtmp_stream = (String)object.get("rtmpstream");

			long port = ((int)Math.random() * 10000) + 1024; 
			
			Backend backend = Main.getInstance().getBackend().get((int)backendNr);
			
			
			try {
				logger.debug("Get Channel");
				
				Channel channel = backend.getChannelByID(backend.getBouquetByID((int)bouquetNr), (int)channelNr);
				
				Configuration configuration = Main.getInstance().getConfiguration();
				
				logger.debug("Get Channel URL");
				
				String inputUrl = backend.getChannelUrl(new BackendListener() {
					@Override
					public void onMessage(String message) {
						// TODO Auto-generated method stub
						sendChannelMessage(message);
					}
					
				}, channel);
				
				logger.debug("tune Channel");
				
				backend.tuneChannel(new BackendListener() {
					@Override
					public void onMessage(String message) {
						// TODO Auto-generated method stub
						sendChannelMessage(message);
					}
					
				}, channel);
											
				logger.debug("Channel url is " + inputUrl);					
				String outputUrl = rtmp_url + "/" + rtmp_stream;
			
				logger.debug("Channel output url is " + outputUrl);							
			
				converter.close();
				
				if (format.equals("FLV")) { 
					
					logger.debug("opening xuggler converter");
					
					converter = new XugglerConverter();
				
					converter.openMedia(inputUrl, backend.getDefaultFormat());
				
					converter.openOutput(outputUrl, ConverterFormatEnum.valueOf(format));
				
					converter.setupReadStreams("fre");					
				
					ConverterCodecEnum audiocodec = ConverterCodecEnum.MP3;
					ConverterCodecEnum videocodec = ConverterCodecEnum.H264;
					if (configuration.getClient().getAudiocodec().equals("flv")) {
						videocodec = ConverterCodecEnum.FLV1;
					}
					if (configuration.getClient().getAudiocodec().equals("aac")) {
						videocodec = ConverterCodecEnum.AAC;
					}
				
					converter.setupWriteStreams(
						videocodec, 
						configuration.getClient().getVideobitrate().intValue(), 
						audiocodec, 
						configuration.getClient().getAudiobitrate().intValue()
					);
					
					converter.start();
				}	
				
				else if (format.equals("WEBM")){
					
					logger.debug("opening webm converter");
					
					converter = new WebMConverter();
					
					converter.openMedia(inputUrl, backend.getDefaultFormat());
					
					JSONObject obj = new JSONObject();
					obj.put("action", "CHANNELSTARTED");
					obj.put("backend", new Long(backendNr));
					obj.put("bouquet", new Long(bouquetNr));
					obj.put("channel", new Long(channelNr));
					obj.put("port", port);
					obj.put("rnd", new Long((int)(Math.random() * 10000)));
					sendMessage(obj);
					
					converter.openOutput("tcp://localhost:" + port + "?listen=1&listen_timeout=10000", ConverterFormatEnum.valueOf(format));
					
					logger.debug("Done opening output");
					
					converter.setupReadStreams("");
					
					ConverterCodecEnum audiocodec = ConverterCodecEnum.VORBIS;
					ConverterCodecEnum videocodec = ConverterCodecEnum.VP8;
					
					converter.setupWriteStreams(videocodec, 
						configuration.getClient().getVideobitrate().intValue(), 
						audiocodec, 
						configuration.getClient().getAudiobitrate().intValue()
					);
					
					converter.start();
					
					logger.debug("Converter started");
					
					return true;
					
				}
				
				
			} catch (ConverterException e1) {
				// TODO Auto-generated catch block
				logger.error("Converter exception : " + e1.getMessage());
				sendChannelFailedMessage(e1.getMessage());
				converter.close();
				return true;
			} catch (BackendException e) {
				// TODO Auto-generated catch block
				logger.error("Backend exception : " + e.getMessage());
				sendChannelFailedMessage(e.getMessage());
				converter.close();
				return true;
			}			
			
												
			JSONObject obj = new JSONObject();
			obj.put("action", "CHANNELSTARTED");
			obj.put("backend", new Long(backendNr));
			obj.put("bouquet", new Long(bouquetNr));
			obj.put("channel", new Long(channelNr));
			obj.put("stream", rtmp_url);
			obj.put("streamname", rtmp_stream);
			sendMessage(obj);
			
			return true;
		}
		
		return false;
		
	}
	
	private void sendChannelFailedMessage(String error) { 			
		JSONObject obj = new JSONObject();
		obj.put("action", "CHANNELFAILED");
		obj.put("error", error);
		sendMessage(obj);
	}
	
	/**
	 * Helper
	 * @param message
	 */
	protected void sendChannelMessage(String message) {
		JSONObject obj = new JSONObject();
		obj.put("action", "CHANNELMESSAGE");
		obj.put("message", message);
		try {
			connection.sendMessage(obj.toJSONString());
		} catch (IOException e) {
			// TODO Auto-generated catch block
			logger.error("Failed to send message");
		}			
	}

	@Override
	protected void doCleanup() {
		// TODO Auto-generated method stub
		converter.close();
	}
	

}
