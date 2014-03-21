<%@ taglib prefix="c" uri="http://java.sun.com/jsp/jstl/core" %>
<%@ page import="org.mytvstream.main.Main" %>
<%
  pageContext.setAttribute("backends", Main.getInstance().getBackend());
  pageContext.setAttribute("server_name", request.getServerName());
   pageContext.setAttribute("stream_name", session.getId());
%>
<!DOCTYPE html>
<html> 
  <head>
    <title>Hello World JSP Page.</title>
     <meta charset="utf-8">
     
    <link rel="stylesheet" href="/jstree/default/style.min.css" />
    <link rel="stylesheet" href="/bootstrap/css/bootstrap.min.css" />    
    <link rel="stylesheet" href="/bootstrap/css/bootstrap-theme.min.css">
    <link rel="stylesheet" href="page.css">
    
    <script src="/javascript/jquery.js"></script>
    <script src="/javascript/jquery.gracefulWebSocket.js"></script>
    <script src="/javascript/jquery.json-2.4.js"></script>
    
    <script src="/bootstrap/js/bootstrap.min.js"></script>
    <script src="/jstree/jstree.min.js"></script>    
    <script src="/javascript/page.js"></script>
    
    
    
    <script>
    
    
    $(function () {
    
      var ws = $.gracefulWebSocket('ws://<c:out value="${server_name}"/>:8085/events/'); 
  
      var bouquet = 0;
      var channel = 0;
      var backend = 0;
  
      $.apply = function(object, config) {
        
        if (object && config && typeof config === 'object') {
            var i, j, k;

            for (i in config) {
                object[i] = config[i];
            }
            
        }

        return object;
      };
      
      $.send_epg_query = function() {
      
          var epgmessage = {
            action : "EPG_QUERY",
            channel : channel,
            bouquet : bouquet,
            backend : backend
          };
           
          ws.send($.toJSON(epgmessage));     
      
      };
    
      $.application_msg = function() {
      
        /**
         * default configuration of the application msg 
         */
         
        var config = {
          type : 'alert_success',
          style : '',          
          target : '#flashcontent',
          time_to_display : 2000,
          text : ''                    
        };
        
        return {
          init : function(apply_config) {        
            $.apply(config,apply_config);
            return this;        
          },
        
          display : function() {
            $('<div>')
            .attr('class', 'alert' + ' ' + config.type + ' ' + config.style)
            .html(config.text)
            .fadeIn('fast')
            .insertBefore($(config.target))  
            .animate({opacity: 1.0}, config.time_to_display)  
            .fadeOut('slow', function()
            {
              $(this).remove();
            });
          }
       };        
              
      };
     
      ws.onmessage = function (event) {
        var messageFromServer = event.data;
        var obj = jQuery.parseJSON( messageFromServer );
        
        if (obj.action == "CHANNELFAILED") {
          //$.channel_msg("Failed to tune channel:" + obj.error, "alert alert-danger");
          $.application_msg().init({
            type : 'alert-danger',
            style : 'channel_msg',
            text : "Failed to tune channel:" + obj.error
          }).display();
        }
        
        if (obj.action == "CHANNELMESSAGE") {
          $.application_msg().init({
            type : 'alert-warning',
            style : 'channel_msg',
            text : obj.message
          }).display();
        }
        
        if (obj.action == "CHANNELSTARTED") {
          
          channel = obj.channel;
          bouquet = obj.bouquet;
          backend = obj.backend;
          
          $("#flashcontent").empty();
          
          $("#flashcontent").append(            
            '<object data="/resources/jaris.swf" id="VideoPlayer" type="application/x-shockwave-flash" height="100%" width="100%"> ' + 
            '<param value="true" name="menu"> ' +             
            '<param value="true" name="allowFullscreen"> ' +
            '<param value="always" name="allowScriptAccess"> ' +
            ' <param value="#000000" name="bgcolor"> ' +
            ' <param value="high" name="quality"> ' +
            ' <param value="opaque" name="wmode"> ' +
            ' <param value="noScale" name="scale"> ' +
            ' <param value="source=<c:out value="${stream_name}"/>&amp;type=video&amp;streamtype=rtmp&amp;controltype=1&amp;autostart=true&amp;controls=true&amp;darkcolor=000000&amp;brightcolor=4c4c4c&amp;controlcolor=FFFFFF&amp;hovercolor=67A8C1&amp;seekcolor=D3D3D3&amp;jsapi=true&amplive=1&amp;server=rtmp://<c:out value="${server_name}"/>/flvplayback" name="flashvars"> ' +
            '</object> '
           );
            
           $.send_epg_query();   
                                
        }
        
        if (obj.action == "EPG_QUERY_RESULT") {
          $.application_msg().init({
            type : 'alert-success',
            style : 'epg_msg',
            text : obj.epgevent,
            time_to_display : 7000
          }).display();
        }
        
      };
    
      $.jstree.defaults.core.themes.variant = "small"; 
      $('#tree_div').jstree();
      
      $('#tree_div').on("changed.jstree", function (e, data) {
        if (data.node.data.channel) {
        
          var myObj = {
            action: "CHANNELSTART", 
            format : "FLV",
            backend : data.node.data.backend,
            bouquet : data.node.data.bouquet,
            channel : data.node.data.channel,
            rtmpurl : 'rtmp://<c:out value="${server_name}"/>/flvplayback',
            rtmpstream : '<c:out value="${stream_name}"/>'  
          };
          
          ws.send($.toJSON(myObj));
          
         // $("#flashcontent").empty(); 
        }
      });
      
      
       
    });
  
    
    </script>    
  </head>
  
  <body>
  
    
    <div class="page-header well" id="header">
      <center><h1>TVStream flash page</h1></center>
    </div>
    
    <div class="container-fluid" id="content">
      <div class="row-fluid fill" >
    
        <!--Sidebar content-->
        <div class="col-md-3 grey_background fill panel" id="channel_list">           
          <div id="tree_div">
            <ul>
              <c:forEach var="backend" items="${backends}"> 
                <li data-jstree='{"icon":"/resources/images/tree.png"}'><c:out value="${backend.getName()}"/>
                  <ul>
                    <c:forEach var="bouquet" items="${backend.getBouquets()}">
                      <li><c:out value="${bouquet.getName()}"/>
                        <ul>
                          <c:forEach var="channel" items="${bouquet.getChannels()}">
                            <li 
                              data-channel=<c:out value="${channel.getID()}"/> 
                              data-bouquet=<c:out value="${bouquet.getID()}"/> 
                              data-backend=<c:out value="${backend.getID()}"/> 
                              data-jstree='{"icon":"/resources/images/film.png"}'
                            >
                            <c:out value="${channel.getNumber()} - ${channel.getName()}"/>
                            </li>
                          </c:forEach>
                        </ul>
                       </li>
                    </c:forEach>
                  </ul> 
                 </li>
              </c:forEach>
            </ul>
          </div>
       </div>
       
       <div class="col-md-9 fill" id="flash">
          <div id="flashcontent" class="fill" />
            <object data="/resources/jaris.swf" 
            id="VideoPlayer" type="application/x-shockwave-flash" height="100%" width="100%">
            <param value="true" name="menu">
            <param value="noScale" name="scale">
            <param value="true" name="allowFullscreen">
            <param value="always" name="allowScriptAccess">
            <param value="#000000" name="bgcolor">
            <param value="high" name="quality">
            <param value="opaque" name="wmode">
            <param value="controls=false&amp;darkcolor=000000&amp;brightcolor=4c4c4c&amp;controlcolor=FFFFFF&amp;hovercolor=67A8C1&amp;seekcolor=D3D3D3" name="flashvars"> 
          </object>
          </div>
       </div>    
     </div>
    </div>
  </div>
 </div>


  </body>
</html>