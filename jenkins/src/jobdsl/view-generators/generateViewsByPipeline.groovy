// ----------------------------------------------------------------------------
// global vars
// ----------------------------------------------------------------------------

def prodName = "${PRODUCT}"
def compName = "${COMPONENT}"
def curPipelineName = "${PIPELINE}"
def pipelinePath="${WORKSPACE}/jenkins/%s/jobdsl/pipelines"
def branchListFileName = "${WORKSPACE}/branchlist.txt"
def branchSuffix = 'branch-pipelines'
def branchList = [:]



// ----------------------------------------------------------------------------
// function defs
// ----------------------------------------------------------------------------

def FindPipelineInfo ( pipelineName, pipelinePath) {

    // ---------------------------------------------------------
    // look for pipeline file in 1 of 2 places
    // 
    // ${WORKSPACE}/jenkins/build/jobdsl/pipelines
    // ${WORKSPACE}/jenkins/src/jobdsl/pipelines
    // 
    // fail the script if not found in either place
    // ---------------------------------------------------------

    def buildDir = 'build'
    def srcDir = 'src'
    def retVal =  LoadPipelineJson ( pipelineName, pipelinePath, buildDir )

    if ( ! retVal ) {
        retVal = LoadPipelineJson ( pipelineName, pipelinePath, srcDir )
    }
    if ( ! retVal ) {
        throw new RuntimeException( "could not find necessary pipeline file" )
    }
    return retVal
}


def LoadPipelineJson ( pipelineName, pipelinePath, subDir ) {

    // ---------------------------------------------------------
    // attempt to load pipeline json file info
    // ---------------------------------------------------------

    def pipelineFile = "${sprintf ( pipelinePath, subDir )}/${pipelineName}.json"
    def retVal = null

    try {
        println "searching for pipelineFile: $pipelineFile"
        retVal = LoadJsonFile ( pipelineFile )
    }
    catch (e) {
        println "couldn't find pipelineFile: $pipelineFile"
    }
    return retVal
}


def ParseBranchFile ( branchFileName, pipelineName, pipelinePath ) {

    // ---------------------------------------------------------
    // reads a branch list file which is just the output of
    // 'git branch -r' and returns a map of
    // [ branchName1 : branchType1, branchName2 : branchType2 ]
    // ---------------------------------------------------------

    def result = [:]

   try {
        def branchListFile = new File ( branchFileName )

        for ( curLine in branchListFile ) {

            def matcher = ( curLine =~ /^.+?\/(\S+?)($|\/(\S+))/ )
            if ( matcher ) {
                def branchType = matcher[0][1]
                def branchName = matcher[0][3]
                if ( ! branchName ) {
                    branchName = branchType
                }
                if ( ! result[branchType] ) {
                    result[branchType] = [
                        "pipelineInfo" : FindPipelineInfo ( pipelineName, pipelinePath ),
                        "branchNames" : []
                    ]
                }
                if ( ! result[branchType]["branchNames"].contains ( branchName ) ) {
                    result[branchType]["branchNames"] << branchName
                }
            }
            println curLine
        }

   }
   catch ( e ) {
        println "\ncould not find necessary branch file ${branchFileName} or pipeline files -- skipping view generation\n"
   }

    println result
    result
}


def LoadJsonFile ( fileName ) {
    def result = null
    try {
        def jsonFile = new File ( fileName )
        result = new groovy.json.JsonSlurper ( ).parse ( jsonFile.newReader ( ) )
    }
    catch ( e ) {
        println "\ncould not find file ${fileName} -- skipping view generation"
    }
    result
}


def CalcBranchTitle ( branchType, branchName ) {
    // ---------------------------------------------------------
    // takes the branchType and branchName and returns the
    // branch title. Only feature, hotfix, and release branches
    // have special titles
    // 
    // Examples
    // branchType/branchName    return value
    // ---------------------------------------
    // feature/newUI            returns feat-newUI
    // release/v11.1.0          returns rel-v11.1
    // hotfix/v11.1.1           returns hot-v11.1.1
    // master                   returns master
    // develop                  returns develop
    // customBranch             returns customBranch
    // ---------------------------------------------------------
    
    def retVal = ''

    switch ( branchType ) {
        case 'master':
            retVal = branchName
            break
        case 'develop':
            retVal = branchName
            break
        case 'feature':
            retVal = 'feat-' + branchName
            break
        case 'release':
            retVal += 'rel-' + branchName
            break
        case 'hotfix':
            retVal += 'hot-' + branchName
            break
        default:
            retVal = branchName
            break
    }

    retVal
}


def GenerateAllViews ( prodName, compName, branchList, branchSuffix ) {
    // ---------------------------------------------------------
    // generates a nested view with all of the sub views for
    // the specified product and component
    // ---------------------------------------------------------

    def fullProjectName = "${prodName}-${compName}"

    view ( type: 'NestedView' ) {

        println ( ' generating level 1 view: ' + fullProjectName )
        name ( fullProjectName )
        views {

            view ( type: 'ListView' ) {
                println ( "  generating level 2 view: view-pipeline-generators" )
                name ( "view-pipeline-generators" )
                jobs {
                    regex ( "create-${fullProjectName}-.*-pipeline" ) 
                }
                columns {
                    buildButton ( )
                    status ( )
                    weather ( )
                    name ( )
                    lastSuccess ( )
                    lastFailure ( )
                }
            }

            view ( type: 'ListView' ) {
                println ( "  generating level 2 view: view-pipeline-cleaners" )
                name ( "view-pipeline-cleaners" )
                jobs {
                    regex ( "delete-${fullProjectName}-.*-pipeline" )
                }
                columns {
                    buildButton ( )
                    status ( )
                    weather ( )
                    name ( )
                    lastSuccess ( )
                    lastFailure ( )
                }
            }

            view ( type: 'ListView' ) {
                println ( "  generating level 2 view: view-analysis-jobs" )
                name ( "view-pipeline-analysis-jobs" )
                jobs {
                    regex ( "${fullProjectName}-.*-analyze-.*" )
                }
                columns {
                    buildButton ( )
                    status ( )
                    weather ( )
                    name ( )
                    lastSuccess ( )
                    lastFailure ( )
                }
            }
            view ( type: 'ListView' ) {
                println ( "  generating level 2 view: view-setup-jobs" )
                name ( "view-setup-jobs" )
                jobs {
                    regex ( "${fullProjectName}-.*(aws|-setup|bucket|rotate).*" )
                }
                columns {
                    buildButton ( )
                    status ( )
                    weather ( )
                    name ( )
                    lastSuccess ( )
                    lastFailure ( )
                }
            }

            for ( branchElem in branchList ) {

                def branchType = branchElem.key
                def branchInfo = branchElem.value
                def branchNameList = branchInfo["branchNames"]
                def branchPipelineList = branchInfo["pipelineInfo"]["steps"]

                // generate pipeline views for all branches
                // 
                for ( branchName in branchNameList ) {

                    // loop through all pipelines for the current branch
                    // 
                    for ( pipelineElem in branchPipelineList ) {

                        def basePipelineName = pipelineElem.key
                        def curPipeline = pipelineElem.value
                        def branchTitle = CalcBranchTitle ( branchType, branchName )
                        def pipelineName = fullProjectName + '-' + branchTitle + '-' + basePipelineName
                        def pipelinePhases = curPipeline["phases"]
                        def pipelineType = ( pipelinePhases.size ( ) > 1 ? 'BuildPipelineView' : 'ListView' )
                        def startPhase = curPipeline["start-phase"]
                        def jobList = pipelinePhases[startPhase]["jobs"]

                        // CJB!!!!
                        // for now, just skip all list views.
                        // need to add a way to specify that we are using an external view generator
                        // 
                        if ( pipelineType == 'ListView' ) {
                            println ( '  skipping pipeline: ' + pipelineName )
                            continue
                        }

                        // generate one leaf-level view per pipeline
                        // 
                        if ( pipelineType == 'ListView' ) {

                            // generate leaf-level ListView
                            // 
                            view ( type: pipelineType ) {

                                println ( '  generating level 2 ListView for pipeline: ' + pipelineName )
                                name ( pipelineName )
                                jobs {
                                    for ( baseJobName in jobList ) {
                                        def fullJobName = fullProjectName + '-' + branchTitle + '-' + baseJobName
                                        println ( '    adding job: ' + fullJobName )
                                        name ( fullJobName )
                                    }
                                }
                                columns {
                                    buildButton ( )
                                    status ( )
                                    weather ( )
                                    name ( )
                                    lastSuccess ( )
                                    lastFailure ( )
                                }
                            }
                        } else {

                            // generate leaf-level BuildPipelineView
                            // 
                            view ( type: pipelineType ) {

                                def startJobName = fullProjectName + '-' + branchTitle + '-' + jobList[0]
                                println ( '  generating level 2 BuildPipelineView for pipeline: ' + pipelineName )
                                println ( '    starting job: ' + startJobName )
                                name ( pipelineName )
                                title ( pipelineName )
                                displayedBuilds ( 10 )
                                selectedJob ( startJobName )
                                alwaysAllowManualTrigger ( true )
                                showPipelineParameters ( true )
                                showPipelineParametersInHeaders ( true )
                                showPipelineDefinitionHeader( true )
                                startsWithParameters( true ) // since 1.26
                                refreshFrequency ( 30 )
                            }            
                        }
                    }
                } 
            }
        }
    }
}



// ----------------------------------------------------------------------------
// main program
// ----------------------------------------------------------------------------

branchList = ParseBranchFile ( branchListFileName, curPipelineName, pipelinePath )
GenerateAllViews ( prodName, compName, branchList, branchSuffix )
