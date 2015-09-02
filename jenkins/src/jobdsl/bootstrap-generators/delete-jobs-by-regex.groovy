job {
	def booleanDesc = """
	when this is checked, the job will only show you what jobs will be deleted<br>
    <b>UNCHECK THIS FLAG</b> when you are ready to actually delete the jobs<br>
	"""

	name ( 'delete-jobs-by-regex' )
    
    parameters {
        booleanParam('preview', true, booleanDesc)
        booleanParam('caseSensitive', true, 'when this is checked, the regular expression will be case-sensitive')
        stringParam('regularExpression', '','')
    }

    label ( 'slingshot' )
	
	def groovyDeleteScript = """
import jenkins.model.*;
import hudson.model.*;
import hudson.tasks.*;
import hudson.plugins.git.*;
import org.eclipse.jgit.transport.*;
import org.jenkinsci.plugins.gitclient.*;
import java.util.regex.Matcher;
import java.util.regex.Pattern;


      // store job parameters in vars

    def sRegularExp = manager.build.getBuildVariables().get( 'regularExpression' )
    def bPreview = ( manager.build.getBuildVariables().get( 'preview' ) == 'true' )
    def bCaseSensitive = ( manager.build.getBuildVariables().get( 'caseSensitive' ) == 'true' )
    def sCurJob = manager.getEnvVariable( 'JOB_NAME' )

      // show the job parameters plus the calculated branch type
      manager.listener.getLogger( ).println( '' )
      manager.listener.getLogger( ).println( '---------------------' )
      manager.listener.getLogger( ).println( 'Job parameters' )
      manager.listener.getLogger( ).println( '---------------------' )
      manager.listener.getLogger( ).println( '[INFO] Regular Expression        : ' + sRegularExp )
      manager.listener.getLogger( ).println( '[INFO] Preview Mode              : ' + bPreview )
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
            manager.listener.getLogger( ).println( '[WARN] the regular expresion matches this job -- this job cannot delete itself!!' )
        }
        else if ( bPreview ) 
        {
            // show the job that would be deleted 
            manager.listener.getLogger( ).println( '[PREVIEW MODE] would delete job: ' + jobObj.getName ( ) )
           counter++;
         }
         else
         {
            // delete the job
            manager.listener.getLogger( ).println( '[INFO] deleting job: ' + jobObj.getName ( ) )
            jobObj.delete()
           counter++;
         }

         Thread.sleep(200)
      }
 }  //for all jobs in one item
}//for items

if ( bPreview ) 
{ 
     manager.listener.getLogger( ).println('[PREVIEW MODE] ' + counter + ' jobs  will be deleted' )
}
else
{
      manager.listener.getLogger( ).println('[INFO] ' + counter + ' jobs deleted' )
}

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
	groovyPostBuild(groovyDeleteScript,Behavior.MarkFailed)

} //publishers-end
}



