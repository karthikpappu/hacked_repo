job {
	def booleanDesc = """
	when this is checked, the specified jobs will be enabled<br>
  otherwise, the specified jobs will be disabled
	"""

	name ( 'enable-disable-jobs-by-regex' )
    
    parameters {
        stringParam('regularExpression', '','' )
        booleanParam( 'enableJobs', true, booleanDesc )
        booleanParam( 'caseSensitive', true, 'when this is checked, the regular expression will be case-sensitive' )
    }

    label ( 'slingshot' )
	
	def groovyEnableDisableScript = """
import jenkins.model.*;
import hudson.model.*;
import hudson.tasks.*;
import hudson.plugins.git.*;
import org.eclipse.jgit.transport.*;
import org.jenkinsci.plugins.gitclient.*;
import java.util.regex.Matcher;
import java.util.regex.Pattern;


      // store job parameters in vars

    def sEnableDisableDesc = 'disable'
    def sRegularExp = manager.build.getBuildVariables().get( 'regularExpression' )
    def bEnableJobs = ( manager.build.getBuildVariables().get( 'enableJobs' ) == 'true' )
    def bCaseSensitive = ( manager.build.getBuildVariables().get( 'caseSensitive' ) == 'true' )
    def sCurJob = manager.getEnvVariable( 'JOB_NAME' )

    if ( bEnableJobs ) {
      sEnableDisableDesc = 'enable'
    }

      // show the job parameters plus the calculated branch type
      manager.listener.getLogger( ).println( '' )
      manager.listener.getLogger( ).println( '---------------------' )
      manager.listener.getLogger( ).println( 'Job parameters' )
      manager.listener.getLogger( ).println( '---------------------' )
      manager.listener.getLogger( ).println( '[INFO] Regular Expression        : ' + sRegularExp )
      manager.listener.getLogger( ).println( '[INFO] Enable/Disable Mode       : ' + sEnableDisableDesc )
      manager.listener.getLogger( ).println( '[INFO] Case Sensitive            : ' + bCaseSensitive )

      // show the job parameters in the build history table
      msgColor = manager.build.getResult( ).color.toString( )
      manager.addShortText(sRegularExp, msgColor, "white", "0px", "white")

      
      // Get all the job names associated with the current Jenkins instance
      //jenkins = Jenkins.getInstance()
      Collection<TopLevelItem> items = Jenkins.getInstance().getItems()
     
      //initialize the counter for counting the number of jobs deleted.
      def counter = 0;


//Check if user entered a valid regex
if (! sRegularExp.equals(".*"))
{

//format the regex
def finalRegExp = ""
if ( bCaseSensitive )
{
    finalRegExp = addRegexChar ( sRegularExp )
} else {
    finalRegExp = "(?i)" + addRegexChar ( sRegularExp )
}



manager.listener.getLogger( ).println( '[INFO] Final Regular Expression  : ' + finalRegExp )

for(TopLevelItem item : items){

// get the list of jobs in this item

Collection<Job> jobs = item.getAllJobs()


for(Job jobObj : jobs)
 {
        // get the job name and check for match with the regex
       if ( jobObj.getName() =~ finalRegExp )
       {
        if ( jobObj.getName() == sCurJob ) {
            manager.listener.getLogger( ).println( '[WARN] the regular expresion matches this job -- this job cannot ' + sEnableDisableDesc + ' itself!!' )
        }
         else
         {
            // enable/disable the job
            if ( bEnableJobs )
            {
                jobObj.enable()
            }
            else
            {
                jobObj.disable()
            }
            manager.listener.getLogger( ).println( '[INFO] ' + sEnableDisableDesc + 'd job: ' + jobObj.getName ( ) )
           counter++;
         }

         Thread.sleep(200)
      }
 }  //for all jobs in one item
}//for items

manager.listener.getLogger( ).println('[INFO] ' + counter + ' jobs ' + sEnableDisableDesc + 'd' )

}//end-if invalid regex
else
{
   manager.listener.getLogger( ).println( 'Please enter a valid regular expression');
}


//Function to add ^ and \$ in the beginning and end of the regex if it doesnt exist
def addRegexChar( String sRegularExpParam)
{
       String finalRegex = sRegularExpParam
       String charAtStart = finalRegex.getAt(0);
       String charAtEnd = finalRegex.getAt((finalRegex.size()) - 1);
       if(!charAtStart.equals("^"))
       {
          finalRegex = "^"+finalRegex;
        }
      if(!charAtEnd.equals("\\\$"))
       {
          finalRegex =  finalRegex+"\\\$";
       }

    return finalRegex;
}
"""

  publishers{
  	groovyPostBuild( groovyEnableDisableScript, Behavior.MarkFailed )
  } //publishers-end

}



