# jobdsl-workflow-seed — the seed for the Jenkins Workflow Engine (JWE)

This project is an  skeleton for the [Jenkins Workflow Engine](https://gitlab.corp.intuit.net/sbg/new-project-onboarding/tree/feature/catapult) tool.
You can use it to quickly bootstrap your projects.

The seed will create a default workflow for a sample project

## Getting Started

To get you started you can simply clone the jobdsl-workflow-seed repository and run the underlying included gradle wrapper build

### Prerequisites

You need git to clone the jobdsl-workflow-seed repository. You can get git from
[https://github.intuit.com/dlethin/jobdsl-workflow-seed](https://github.intuit.com/dlethin/jobdsl-workflow-seed).

#### Clone jobdsl-workflow-seed

Clone the jobdsl-workflow-seed repository using [git][git]:

```
git clone --origin seed https://github.intuit.com/dlethin/jobdsl-workflow-seed.git
cd jobdsl-workflow-seed
```

If you just want to start a new project without the jobdsl-workflow-seed commit history then you can do:

```bash
git clone --origin seed --depth=1 https://github.intuit.com/dlethin/jobdsl-workflow-seed.git <your-project-name>
```

The `depth=1` tells git to only pull down one commit worth of historical data.

#### Create a new repository in github or gitlab
Pick your favorite git repo server and create a repository.  Make sure not to pre-populate it with any files/content.  You will do that from the command line.

#### Connect your new origin repo and push contents

```
git remote add origin git@github.intuit.com:path/to/mynewrepo.git
git push -u origin master
```

At this point, you should see the contents of your initial seed project pushed to your origin repo and your local repo ready to go, tied to the origin with no changes:

```
% git status
On branch master
Your branch is up-to-date with 'origin/master'.

nothing to commit, working directory clean
```

## Running your seed job from jenkins

### Prereqs

You will need to have the following plugins installed in jenkins

* gradle-plugin
* jobdsl-plugin
 
### Steps

Create a new freestyle project on your jenkins server

You will need the following:

#### job parameters
  
  * INITIAL_BRANCHES - string param (default: "master"")
  * PIPELINE - string param (default: "java_app_workflow")
  * COMPONENT - string
  * PRODUCT - string
  * SOURCE_REPOSITORY - string (this is the path to your project's source code)
  
#### restrict where this job can be run

Currently this job must be run on the jenkins **master**

*This is because the jobdsl script needs find some supporting files on the classpath and I think there is a bug in engine code which is not working correctly when run on a slave.*
  
#### inject enviornment variables:

You need to define the following env variables:

* GRADLE_OPTS=-Xms768m -Xmx1024m -XX:MaxPermSize=512m
* JOBDSL_ROOTDIR=${WORKSPACE}/build/jobdsl   - This is needed for the jobdsl root script to find its code/configuration files
  
#### scm section

  * The git path and credentials to your team's seed project you created earlier
 

#### build steps


##### invoke gradle build:

This is needed to stitch together a working directory which contains the JWE engine code/configuration along with your workflow templates/configuration

*  Use Gradle Wrapper: check
*  From Root Build Script Dir: check
*  Build Step description:  Assemble the Jenkins Workflow Engine Working directory
*  Switches: --no-daemon --refresh-dependencies
*  Tasks: clean copyJobDslFiles

##### process Job DSLs:

This is the build step that executes the JWE engine. There are two ways to do this.  The preference is to do the first way, but I'm getting mixed messages on whether or not its working.  If it doesn't, fall back to the 2nd way:

##### Method 1 - call a script from your job's workspace

* Look on Filesystem: selected
* DSL Scripts: build/jobdsl/jobdsl.groovy

##### Method 2 - embed the script to run inside the text box

*Note: This way is not preferred because if we make changes to the initial bootscrapping dsl script, then you will need to add those changes into your script. Ideally if you run into a problem with method #1 we can solve it, but this method is here as a backup*

* Use the provided DSL script: selected
* DSL Script:

```
import com.intuit.tools.devops.workflow.jenkins.*

// Establish an initial context, supplying reference to "this" script
// and the working directory
def pipelineContext = new PipelineContext(this,
	"${JOBDSL_ROOTDIR}")

// Create the initial toolkit
def toolkit = DefaultJobDslToolkitFactory.create(pipelineContext)

// Get the pipeline builder and create the flows
def pipelineBuilder = toolkit.getPipelineBuilder()
pipelineBuilder.createAllWorkFlows()
```

* Advanced Settings:
  * Additional classpath:
  
```
build/jobdsl
```  


## Run the build from the command line

The seed project includes a gradle build wrapper for running jobdsl from the command line. the gradle task is *jobDsl*

```
./gradlew clean jobDsl
```

This will do the following:

* download the referenced gradle distribution if you have not downloaded it before
* execute the clean task -- This essentially deletes the *build* subdirectory (which won't actually exist the first time you run this)
* execute the jobDsl task - This executes the job-dsl-plugin locally, and the jobs/views defined in the workflow get created into *build/jobs* and *build/views* directory. Note you can follow the task dependencies as you can see there are a lot of earlier tasks that get run:


```
./gradlew clean jobDsl
You are running the build with the Intuit Payments QBMS Gradle distribution
:clean
:explodeWorkflowEngine
:copyJobDslFiles
:createTargetDirs
:jobDsl
processing: jobdsl.groovy
Processing DSL script jobdsl.groovy
...
```


### Take a look at the results

```
% find build/jobs
build/jobs
build/jobs/qbo-core-build-environment.xml
build/jobs/qbo-core-developer-build-commit.xml
build/jobs/qbo-core-developer-build-secondary.xml
build/jobs/qbo-core-developer-deploy-1shard.xml
build/jobs/qbo-core-developer-deploy-ci.xml
build/jobs/qbo-core-developer-deploy-perf.xml
build/jobs/qbo-core-developer-deploy-qa.xml
build/jobs/qbo-core-developer-deploy-unittests.xml
build/jobs/qbo-core-developer-merge-in.xml
build/jobs/qbo-core-developer-merge-out.xml
build/jobs/qbo-core-developer-test-1shard.xml
build/jobs/qbo-core-developer-test-ci.xml
build/jobs/qbo-core-developer-test-perf.xml
build/jobs/qbo-core-developer-test-qa.xml
build/jobs/qbo-core-developer-test-unittests.xml
% find build/views/
build/views/
build/views//qbo-core-create-environment.xml
build/views//qbo-core-developer-commit.xml
build/views//qbo-core-developer-merge-in.xml
build/views//qbo-core-developer-merge-out.xml
build/views//qbo-core-developer-secondary.xml
```

### Where did the content for these jobs/views come from?

Here are some clues if you want to start exploring.

* The directory where jobdsl is run out of is *build/jobdsl*.  Looks at the directory contents there.
* The specific files that jobdsl executes is *build/jobdsl/jobdsl.groovy* - check out the contents
* The default job template for all jobs is *build/jobdsl/templates//defaultJob.groovy* 
* The product/sample component names come from the *gradle.properties* file. Try passing *-Pproduct=blah -Pcomponent=yo* on the gradle command line and see what happens

## How do I start customizing behavior?

### Determining which pipeline to build

The JWE *currently* determines which pipeline it wants to build by reading the **PIPELINE** variable. This is either defined in the params section of your seed job, or if you are using the gradle command line, it is specified in the build.gradle file like this:

```
task('jobDsl', dependsOn: ['createTargetDirs','explodeWorkflowEngine','copyJobDslFiles']) << {

    def map = [
        'INITIAL_BRANCHES': "master",
        
        "PIPELINE" : pipeline,
        "PRODUCT" : product,
        "COMPONENT" : component,
        "SOURCE_REPOSITORY" : sourceRepository,
        // provided by jenkins
        "JOBDSL_ROOTDIR" : scriptDir
    ]

    File wd = scriptDir
    URL wdURL = wd.toURI().toURL()

    FileJobManagement jm = new MyFileJobManagement(wd,jobDir,viewDir)
    jm.parameters.putAll(map)

    def scripts = ['jobdsl.groovy']

	...
```

### Format of the **pipeline.json** file

Here is some info on pipelines along with a sample:

 * A pipeline has a name and description
 * It has a collection of flows
 * Each flow is a linked list of phases
   * A flow defines a *start-phase*
   * Each phase has a collection of jobs that run in parallel
   * there is a *next-phase* setting which will run when all the parallel jobs in the phase are complete.
 * Phases are *currently* not optional

```
{
    "name" : "simple-java-workflow",
    "desc" : "standard workflow for SBG Java web applications as defined at https://wiki.intuit.com/download/attachments/268088046/sbg_simple_java_pipeline.png?version=1&modificationDate=1416857400000&api=v2",
	
	"flows" : {

		"delivery-pipeline" : {
			"start-phase" : "commit",

			"phases" : {
				"commit" : {
					"desc" : "this phase builds the java app and run unit tests deploy to nexus or save the artifact with the jenkins build",
					"jobs" : ["build-commit"],
					"next-phase" : "run_analysis"
				},

				"run_analysis" : {
					"desc" : "this phase performs analysis and localization tasks on the build artifact",
					"jobs" : ["analyze-static-code","analyze-security","analyze-globalization"],
					"next-phase" : "deploy_ci"
				},
```

### jobs.json & overriding job definitions

jobs.json defines all the jobs that can be referenced within a pipeline.  The format looks like this:

```
{
	"build-commit" : {
		"sub-jobs" : []
		"string-params": {
			"key" : "value"
		}
		"manual" : false  //default is false
	},

}

 
```
 * jobs can be marked as manual if they require human intervention to trigger their execution in a pipeline
 * sub-jobs are can be used if you want to inject additional jobs to run after a job is run.
 
The jobs.json file defines the common definition of jobs for all projects, but you can customized the definition of a job for a given product/component combination by providing the following file:

````
	pipelines/${PRODUCT}/${PRODUCT}-${COMPONENT}.json
````

It is in that file that you can override any setting within a job/jobs.  Any setting that you don't override will be inherited from the jobs.json file

### job templates

The content of the jenkins job definition for jobs in a pipeline to be created come from templates out of the *templates* directory.  For example, the JWE looks for a file called *templates/build-commit.groovy* when trying to build the build-commit job.     If it does not find a given template,  it will default to the *defaultJob.groovy* template

There is a good amount of documentation on writing templates detailed in the JWE README found **[here](https://gitlab.corp.intuit.net/sbg/new-project-onboarding/blob/feature/catapult/README.md)**

### Advanced Customization ###

Some of the functionality within the JWE is controlled by *closures* that can be overriden by devops teams when needed.

### jobNamer.groovy ###

This determines the policy for how a particular job is named within the JWE

```
def c = { jobInfoList, project, baseJob, branch = '' ->
    // --------------------------------------------------------------------------
	// generate the job (maybe add sub-jobs)
	// --------------------------------------------------------------------------
	def jobDef = jobInfoList[baseJob]
	def result = ''

	if ( jobDef ) {
		if ( jobDef['existing'] ) {
			result = baseJob
		} else {
			def branch_title = '-'
			if ( branch != '' ) {
				branch_title += branch + '-'
			}
			result = "${project.name}" + branch_title + baseJob
		}
	}

	result
}
```

### projectSelector.groovy ###

This determines which jobs are going to be processed by the engine. Here is current default implementation:

```
def c = {
		// PRODUCT & COMPONENT are env variables passed to the jobDsl plugin
        return ["${ctx.jobDslParent.PRODUCT}-${ctx.jobDslParent.COMPONENT}"]
}

```

### projectModelBuilder.groovy ###

The *long-term* goal for Jenkins onboarding is to pull the definition of a project directly from a project.json file stored in the project's scm repository.  This file will most likly be created with the help of a portal application which can interview developers based on a predefined schema.

At this point the onboarding portal does not exist, so the JWE needs to get its project model definition from elsewhere so the templates can have access to that info to make inteligent decisions on how to populate the jenkins job.

Here is the default implementation of the projectModelBuilder:

```
{ projectName ->

	// Use groovy's helpful JsonBuilder to easily define a Json structure
	// using closures
	def projectBuilder = new groovy.json.JsonBuilder()

	projectBuilder {
    	// Need to flesh out this project json file more
      product("${ctx.jobDslParent.PRODUCT}")
      component("${ctx.jobDslParent.COMPONENT}")
      scm {
         git {
            repo "${ctx.jobDslParent.SOURCE_REPOSITORY}"
         }
      }
   }

   
   return new groovy.json.JsonSlurper( ).parseText(projectBuilder.toString())
}

```
*NOTE there is not a good amount of definition to a product at this point.  Ideally we will define a standard all devops teams could use, or deveops teams could define there own (If they know what they are doing)

