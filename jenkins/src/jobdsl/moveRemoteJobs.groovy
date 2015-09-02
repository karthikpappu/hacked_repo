import jenkins.model.*;
import hudson.*;
import hudson.model.*;
import hudson.tasks.*;
import hudson.plugins.*;
import org.jenkinsci.plugins.ParameterizedRemoteTrigger.*;


// ---------------------------------------------------------------------------------------
// ---------------------------------------------------------------------------------------
//  
// Class definitions
// 
// ---------------------------------------------------------------------------------------
// ---------------------------------------------------------------------------------------

public class LogWriter {

	// ------------
	// data members
	// ------------
	// 
	def localOut = null


	// ------------
	// methods
	// ------------
	// 
	public LogWriter ( outStream ) {
		localOut = outStream
	}

	public ShowHeader ( msg = null ) {
		if ( !msg ) { msg = '' }
		localOut.println ( '' )
		this.ShowInfo ( '--------------------------------------------------------------------------------' )
		this.ShowInfo ( msg )
		this.ShowInfo ( '--------------------------------------------------------------------------------' )
	}

	public ShowInfo ( msg = null ) {
		if ( msg && ( msg != '' ) ) {
			localOut.println ( '[info] ' + msg )
		} else {
			localOut.println ( '' )
		}
	}

	public ShowWarn ( msg = null ) {
		if ( !msg ) { msg = '' }
		localOut.println ( '[WARNING] ' + msg )
	}
}


public class JenkinsJobMover {

	// ------------
	// data members
	// ------------
	// 
	def localJenkins = null
	def localRemoteTriggerPlugin = null
	def remoteJenkinsServers = null
	def remoteJobsFilePath = null
	def remoteJobsInfo = null
	def log = null

	private def connectionInfoMap = [:]


	// ------------
	// methods
	// ------------
	// 
	public JenkinsJobMover ( jenkinsInstance, remoteJobsJsonFilePath, outStream ) {

		// --------------------------------------------------------------------
		// 
		// set up log writer
		// store the local jenkins instance object
		// get remote jenkins server info from the parameterized remote trigger plugin
		// get the path to the json file of the jobs that are to be moved
		// 
		// --------------------------------------------------------------------

		log = new LogWriter ( outStream )
		try {
			localJenkins = jenkinsInstance
			localRemoteTriggerPlugin = localJenkins.getDescriptor ( 'org.jenkinsci.plugins.ParameterizedRemoteTrigger.RemoteBuildConfiguration' )
			remoteJenkinsServers = localRemoteTriggerPlugin.getRemoteSites ( )
			remoteJobsFilePath = remoteJobsJsonFilePath
		}
		catch ( e ) {
			log.ShowWarn ( 'could not look up remote site info from the Parameterized Remote Trigger plugin on this Jenkins instance' )
		}
	}


	public FindRemoteJobs ( ) {

		// --------------------------------------------------------------------
		// 
		log.ShowHeader ( 'check for generated jobs that are intended for remote jenkins servers' )
		// 
		// --------------------------------------------------------------------

		def remoteJobsJsonFile = null

		try {
			remoteJobsJsonFile = new File ( remoteJobsFilePath )
			remoteJobsInfo = new groovy.json.JsonSlurper ( ).parseText ( remoteJobsJsonFile.text )
			
			log.ShowInfo ( 'the following jobs will be moved to remote jenkins servers' )
			for ( jobName in remoteJobsInfo.keySet ( ) ) {
				log.ShowInfo ( 'job name              : ' + jobName )
				log.ShowInfo ( 'remote jenkins server : ' + remoteJobsInfo[jobName]['host'] )
			}
			log.ShowInfo ( )
			return remoteJobsInfo
		}
		catch ( e ) {
			log.ShowInfo ( 'could not find remote jobs info file: ' + remoteJobsFilePath )
			log.ShowInfo ( ' no jobs will be moved to remote jenkins servers' )
			log.ShowInfo ( )
			return null
		}
	}


	public int MoveRemoteJobs ( ) {

		// --------------------------------------------------------------------
		// 
		// try to move all remote jobs to their respective remote servers
		// keep going even if some jobs fail when we try to move them
		// return 0 for success only if all jobs were successfully moved
		// 
		// --------------------------------------------------------------------

		def retVal = 0
		log.ShowHeader ( 'moving remote jobs to remote jenkins servers' )

		for ( jobName in remoteJobsInfo.keySet ( ) ) {
			if ( !MoveOneRemoteJob ( jobName ) ) {
				retVal = 1
			}
		}

		return retVal
	}


	public Boolean MoveOneRemoteJob ( jobName, deleteLocal = true ) {

		// --------------------------------------------------------------------
		// 
		// move a single job to the remote jenkins server specified in the
		// remoteJobsInfo data structure
		// 
		// --------------------------------------------------------------------

		// connect to job's remote server
		// read in local job's config
		// check if job already exists on remote server
		// if job exists, use job update api and write local job's config
		// if job does not exist, use create job api and write local job's config
		// delete local job

		def retVal = false
		log.ShowInfo ( 'moving remote job: ' +  jobName )

		if ( GetRemoteJenkinsConnectionInfo ( remoteJobsInfo[jobName]['host'] ) ) {
			if ( GetRemoteJenkinsJob ( jobName ) ) {
				retVal = UpdateRemoteJenkinsJob ( jobName )
			} else {
				retVal = CreateRemoteJenkinsJob( jobName )
			}
		}

		if ( retVal && deleteLocal ) {
			localJenkins.getItem ( jobName ).delete ( )
			log.ShowInfo ( 'deleted copy of job on local jenkins server' )
		}
		log.ShowInfo ( )
		return retVal
	}


	public Boolean GetRemoteJenkinsConnectionInfo ( remoteServerName ) {

		// --------------------------------------------------------------------
		// 
		// search for connection info for this remote jenkins server
		// if we've already found the connection info, just return it
		// 
		// --------------------------------------------------------------------

		// check if server connect info already found
		// 
		if ( connectionInfoMap[remoteServerName] ) {
			return true
		}

		// search sites for the specified remote server name
		// 
		def remoteSite = null
		def connectionInfo = ['url' : null, 'client' : null ]

		log.ShowInfo ( 'searching parameterized remote trigger plugin for remote jenkins server: ' + remoteServerName )
		for ( oneSite in remoteJenkinsServers ) {
			if ( oneSite.getDisplayName ( ) == remoteServerName ) {
				remoteSite = oneSite
				log.ShowInfo ( 'found remote jenkins server info' )
				break
			}
		}

		// get connection to the found remote server
		// 
		if ( remoteSite ) {
			for ( curAuthObj in remoteSite.getAuth ( ) ) {				
				if ( curAuthObj.getPassword( ) != '' ) {
					connectionInfo['url'] = remoteSite.getAddress ( )
					connectionInfo['auth'] = curAuthObj
					connectionInfoMap[remoteServerName] = connectionInfo
					break
				}
			}
			if ( !connectionInfoMap[remoteServerName] ) {
				log.ShowWarn ( 'no authentication info is set up for thie remote jenkins server in the Parameterized Remote Trigger Plugin' )
				log.ShowWarn ( 'cannot move any jobs to this remote jenkins server until the authentication is configured in the Parameterized Remote Trigger Plugin on this local jenkins server' )
			}

		} else {
			log.ShowWarn ( 'this remote jenkins server is not set up in the Parameterized Remote Trigger Plugin' )
			log.ShowWarn ( 'cannot move any jobs to this remote jenkins server until it is configured in the Parameterized Remote Trigger Plugin on this local jenkins server' )
		}

		// simple validation of connect info before adding it to the list
		// 
		return ( connectionInfoMap[remoteServerName] != null )
	}


	public Boolean GetRemoteJenkinsJob ( jobName ) {

		// --------------------------------------------------------------------
		// 
		log.ShowInfo ( 'checking if job already exists' )
		// 
		// --------------------------------------------------------------------

		def remoteServerName = remoteJobsInfo[jobName]['host']
		def auth = connectionInfoMap[remoteServerName]['auth']
		def url = connectionInfoMap[remoteServerName]['url']
		def jobUrl = "${url}job/${jobName}/config.xml"
		def response = GetUrlRequest ( jobUrl.toURL ( ), auth )

		if ( response.code == 200 ) {
			log.ShowInfo ( 'found existing remote job: ' + jobName )
			return true
		} else {
			log.ShowInfo ( 'remote job does not exist: ' + jobName )
			return false			
		}
	}


	public Boolean UpdateRemoteJenkinsJob ( jobName ) {

		// --------------------------------------------------------------------
		// 
		log.ShowInfo ( 'updating existing job' )
		// 
		// --------------------------------------------------------------------

		def newJobConfig = localJenkins.getItem ( jobName ).getConfigFile ( )
		def remoteServerName = remoteJobsInfo[jobName]['host']
		def auth = connectionInfoMap[remoteServerName]['auth']
		def url = connectionInfoMap[remoteServerName]['url']
		def jobUrl = "${url}job/${jobName}/config.xml"
		def response = PostUrlRequest ( jobUrl.toURL ( ), auth, newJobConfig )

		if ( response.code == 200 ) {
			log.ShowInfo ( 'updated existing remote job: ' + jobName )
			return true
		} else {
			log.ShowInfo ( 'could not update existing remote job: ' + jobName )
			return false			
		}
	}


	public Boolean CreateRemoteJenkinsJob ( jobName ) {

		// --------------------------------------------------------------------
		// 
		log.ShowInfo ( 'creating new job' )
		// 
		// --------------------------------------------------------------------

		def newJobConfig = localJenkins.getItem ( jobName ).getConfigFile ( )
		def remoteServerName = remoteJobsInfo[jobName]['host']
		def auth = connectionInfoMap[remoteServerName]['auth']
		def url = connectionInfoMap[remoteServerName]['url']
		def jobUrl = "${url}createItem?name=${jobName}"
		def response = PostUrlRequest ( jobUrl.toURL ( ), auth, newJobConfig )

		if ( response.code == 200 ) {
			log.ShowInfo ( 'created remote job: ' + jobName )
			return true
		} else {
			log.ShowInfo ( 'could not create remote job: ' + jobName )
			return false			
		}
	}


	private GetUrlRequest ( url, auth ) {

		// --------------------------------------------------------------------
		// 
		// generic way to send an http request with authorization
		// 
		// --------------------------------------------------------------------

		def conn = url.openConnection ( )
		def authStr = "${auth.getUsername ( )}:${auth.getPassword ( )}".getBytes ( ).encodeBase64 ( ).toString ( )
		def retVal = [ 'code' : 0, 'text' : '' ]

		try {
			log.ShowInfo ( 'http GET request to: ' + url )
			conn.setRequestMethod ( 'GET' )
			conn.setRequestProperty ( "Authorization", "Basic ${authStr}" )

			if ( !conn.connected ) {
				retVal['code'] = conn.responseCode
				conn.connect ( )
			}

	
			retVal['code'] = conn.responseCode
			retVal['text'] = conn.content.text
	
		}
		catch ( e ) {
			log.ShowInfo ( 'caught exceptiong during http GET request to: ' + url )
		}

			log.ShowInfo ( 'http response code: ' + conn.responseCode )
		return retVal
	}


	private PostUrlRequest ( url, auth, content ) {

		// --------------------------------------------------------------------
		// 
		// generic way to send an http request with authorization
		// 
		// --------------------------------------------------------------------

		def conn = url.openConnection ( )
		def authStr = "${auth.getUsername ( )}:${auth.getPassword ( )}".getBytes ( ).encodeBase64 ( ).toString ( )
		def responseText = ''
		def retVal = [ 'code' : 0, 'text' : '' ]

		try {
			log.ShowInfo ( 'http POST request to: ' + url )
			conn.setRequestMethod ( 'POST' )
			conn.setRequestProperty ( "Authorization", "Basic ${authStr}" )
			conn.setRequestProperty ( "Content-Type", "application/xml" )
			conn.setDoOutput ( true )

			def connOutStream = conn.getOutputStream ( )
			connOutStream.withWriter { Writer connWriter -> 
				connWriter << content.asString ( )
			}
			def connInStream = conn.getInputStream ( )
			responseText = connInStream.withReader { Reader connReader ->
				connReader.text
			}
			log.ShowInfo ( 'POST request content sent' )

		}
		catch ( e ) {
			log.ShowInfo ( 'caught exceptiong during http POST request to: ' + url )
		}

		log.ShowInfo ( 'http response code: ' + conn.responseCode )
		retVal['code'] = conn.responseCode
		retVal['text'] = responseText
		return retVal
	}

}



// ---------------------------------------------------------------------------------------
// ---------------------------------------------------------------------------------------
// 
// Main program
// 
// ---------------------------------------------------------------------------------------
// ---------------------------------------------------------------------------------------

def gRemoteJobsFilePath = build.getEnvironment ( ).get ( 'JOBDSL_ROOTDIR' ) + '/remoteJobsInfo.json'
def gMover = new JenkinsJobMover ( Jenkins.getInstance ( ), gRemoteJobsFilePath, out )
def gExitCode = 0

if ( gMover.FindRemoteJobs ( ) ) {
	gExitCode = gMover.MoveRemoteJobs ( )
}
return gExitCode

