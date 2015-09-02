def c = {

    // use configure block to specify the job xml data for the ParameterizedRemoteTrigger plugin
    // 
    configure { project ->
        project / builders << 'org.jenkinsci.plugins.ParameterizedRemoteTrigger.RemoteBuildConfiguration'(plugin: 'Parameterized-Remote-Trigger@2.1.3') {
            token 'B745F27E-CFD9-4024-BF6B-B9E2C6B9F2AD'
            remoteJenkinsName 'preprod deploy server (oppdfmsis300.corp.intuit.net)'
            job 'create-qbo-preprod-in-aws'
            shouldNotFailBuild 'false'
            pollInterval '10'
            connectionRetryLimit '5'
            preventRemoteBuildQueue 'false'
            blockBuildUntilComplete 'true'

            // note: it seems that parameters must be defined twice
            //   once as a string of 'parameters' separated by the newline character
            //   once as again individually as a 'param' string
            // 
            def remoteParams = [ 'CLUSTER=59', 'PROJECT_NAME=qbo-monolith-commit-build', 'DEPLOY=true' ]
            parameters remoteParams.join ( "\n" )
            parameterList {
                for ( param in remoteParams ) {
                    string param
                }
            }
        }
    }
}


