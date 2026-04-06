const {  inhiveClient } = require('./client.js');
const inhive = require("./inhive_grpc_web_pb.js");

function openConnectionPage() {
    
        $("#extension-list-container").show();
        $("#extension-page-container").hide();
        $("#connection-page").show();
        connect();
        $("#connect-button").click(async () => {
            const hsetting_request = new inhive.ChangeHiddifySettingsRequest();
            hsetting_request.setHiddifySettingsJson($("#inhive-settings").val());
            try{
                const hres=await inhiveClient.changeHiddifySettings(hsetting_request, {});
            }catch(err){
                $("#inhive-settings").val("")
                console.log(err)
            }
            
            const parse_request = new inhive.ParseRequest();
            parse_request.setContent($("#config-content").val());
            try{
                const pres=await inhiveClient.parse(parse_request, {});
                if (pres.getResponseCode() !== inhive.ResponseCode.OK){
                    alert(pres.getMessage());
                    return
                }
                $("#config-content").val(pres.getContent());
            }catch(err){
                console.log(err)
                alert(JSON.stringify(err))
                                return
            }

            const request = new inhive.StartRequest();
    
            request.setConfigContent($("#config-content").val());
            request.setEnableRawConfig(false);
            try{
                const res=await inhiveClient.start(request, {});
                console.log(res.getCoreState(),res.getMessage())
                    handleCoreStatus(res.getCoreState());
            }catch(err){
                console.log(err)
                alert(JSON.stringify(err))
                return
            }

            
        })

        $("#disconnect-button").click(async () => {
            const request = new inhive.Empty();
            try{
                const res=await inhiveClient.stop(request, {});
                console.log(res.getCoreState(),res.getMessage())
                handleCoreStatus(res.getCoreState());
            }catch(err){
                console.log(err)
                alert(JSON.stringify(err))
                return
            }
        })
}


function connect(){
    const request = new inhive.Empty();
    const stream = inhiveClient.coreInfoListener(request, {});
    stream.on('data', (response) => {
        console.log('Receving ',response);
        handleCoreStatus(response);
    });
    
    stream.on('error', (err) => {
        console.error('Error opening extension page:', err);
        // openExtensionPage(extensionId);
    });
    
    stream.on('end', () => {
        console.log('Stream ended');
        setTimeout(connect, 1000);
        
    });
}


function handleCoreStatus(status){
    if (status == inhive.CoreState.STOPPED){
        $("#connection-before-connect").show();
        $("#connection-connecting").hide();
    }else{
        $("#connection-before-connect").hide();
        $("#connection-connecting").show();
        if (status == inhive.CoreState.STARTING){
            $("#connection-status").text("Starting");
            $("#connection-status").css("color", "yellow");
        }else if (status == inhive.CoreState.STOPPING){
            $("#connection-status").text("Stopping");
            $("#connection-status").css("color", "red");
        }else if (status == inhive.CoreState.STARTED){
            $("#connection-status").text("Connected");
            $("#connection-status").css("color", "green");
        }
    }
}


module.exports = { openConnectionPage };