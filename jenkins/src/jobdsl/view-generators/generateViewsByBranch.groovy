// ----------------------------------------------------------------------------
// global vars
// ----------------------------------------------------------------------------

def prodName = "${PRODUCT}"
def compName = "${COMPONENT}"
def curPipeline = "${PIPELINE}"
def pipelinePath="${WORKSPACE}/jenkins/build/jobdsl/pipelines"
def pipelineFilePrefix = ''
def branchListFileName = "${WORKSPACE}/branchlist.txt"
def branchSuffix = 'branch-pipelines'
def branchList = [:]



// ----------------------------------------------------------------------------
// function defs
// ----------------------------------------------------------------------------

def GetPipelineFilePrefix ( curPipeline ) {

    def result = ''
    def matcher = curPipeline =~ /^(.*?_.*?)_/
    if ( matcher ) {
        result = matcher[0][1]
    }
    result
}

def ParseBranchFile ( branchFileName, pipelinePath, pipelineFilePrefix ) {

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
                    def pipelineFile = "${pipelinePath}/${pipelineFilePrefix}_${branchType}_workflow.json"
                    result[branchType] = [
                        "pipelineFile" : pipelineFile,
                        "pipelineInfo" : LoadJsonFile ( pipelineFile ),
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
        println "\ncould not find file ${branchFileName} -- skipping view generation\n"
    }
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
                println ( "  generating level 2 view: create-${fullProjectName}-branch-and-pipeline" )
                name ( "create-${fullProjectName}-branch-and-pipeline" )
                jobs {
                    regex ( "${fullProjectName}-.*-pipeline-generator" )
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
                println ( "  generating level 2 view: delete-${fullProjectName}-branch-and-pipeline" )
                name ( "delete-${fullProjectName}-branch-and-pipeline" )
                jobs {
                    regex ( "${fullProjectName}-.*-delete-pipeline" )
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
                def topViewName = "view-${fullProjectName}-${branchType}-${branchSuffix}"

                if ( ['master', 'develop'].contains ( branchType ) ) {

                    // generate one nested view per branch name
                    // 
                    for ( branchName in branchNameList ) {

                        view ( type: NestedView ) {

                            println ( '   generating level 3 view for branch: ' + branchName )
                            name ( topViewName )
                            views {

                                // loop through all pipelines for this branch
                                // 
                                for ( pipelineElem in branchPipelineList ) {

                                    def basePipelineName = pipelineElem.key
                                    def curPipeline = pipelineElem.value
                                    def pipelineName = fullProjectName + '-' + branchName + '-' + basePipelineName
                                    def pipelinePhases = curPipeline["phases"]
                                    def pipelineType = ( pipelinePhases.size ( ) > 1 ? 'BuildPipelineView' : 'ListView' )
                                    def startPhase = curPipeline["start-phase"]
                                    def jobList = pipelinePhases[startPhase]["jobs"]

                                    // generate one leaf-level view per pipeline
                                    // 
                                    if ( pipelineType == 'ListView' ) {

                                        // generate leaf-level ListView
                                        // 
                                        view ( type: pipelineType ) {

                                            println ( '    generating level 4 ListView for pipeline: ' + pipelineName )
                                            name ( pipelineName )
                                            jobs {
                                                for ( baseJobName in jobList ) {
                                                    def fullJobName = fullProjectName + '-' + branchName + '-' + baseJobName
                                                    println ( '     adding job: ' + fullJobName )
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

                                            def startJobName = fullProjectName + '-' + branchName + '-' + jobList[0]
                                            println ( '    generating level 4 BuildPipelineView for pipeline: ' + pipelineName )
                                            println ( '     starting job: ' + startJobName )
                                            name ( pipelineName )
                                            title ( pipelineName )
                                            displayedBuilds ( 5 )
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
                } else {

                    // generate one nested view per branch type
                    // 
                    view ( type: NestedView ) {

                        println ( '   generating level 3 view for branch type: ' + branchType )
                        name ( topViewName )
                        views {

                            // generate one sub-nested view per branch name
                            // 
                            for ( branchName in branchNameList ) {

                                view ( type: NestedView ) {

                                    println ( '    generating level 4 sub-view for branch: ' + branchName )
                                    name ( "${fullProjectName}-${branchName}-${branchSuffix}" )
                                    views {

                                        // loop through all pipelines for this branch
                                        // 
                                        for ( pipelineElem in branchPipelineList ) {

                                            def basePipelineName = pipelineElem.key
                                            def curPipeline = pipelineElem.value
                                            def pipelineName = fullProjectName + '-' + branchName + '-' + basePipelineName
                                            def pipelinePhases = curPipeline["phases"]
                                            def pipelineType = ( pipelinePhases.size ( ) > 1 ? 'BuildPipelineView' : 'ListView' )
                                            def startPhase = curPipeline["start-phase"]
                                            def jobList = pipelinePhases[startPhase]["jobs"]

                                            // generate one leaf-level view per pipeline
                                            // 
                                            if ( pipelineType == 'ListView' ) {

                                                // generate leaf-level ListView
                                                // 
                                                view ( type: pipelineType ) {

                                                    println ( '    generating level 4 ListView for pipeline: ' + pipelineName )
                                                    name ( pipelineName )
                                                    jobs {
                                                        for ( baseJobName in jobList ) {
                                                            def fullJobName = fullProjectName + '-' + branchName + '-' + baseJobName
                                                            println ( '     adding job: ' + fullJobName )
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

                                                    def startJobName = fullProjectName + '-' + branchName + '-' + jobList[0]
                                                    println ( '    generating level 4 BuildPipelineView for pipeline: ' + pipelineName )
                                                    println ( '     starting job: ' + startJobName )
                                                    name ( pipelineName )
                                                    title ( pipelineName )
                                                    displayedBuilds ( 10 )
                                                    selectedJob ( startJobName )
                                                    triggerOnlyLatestJob ( true )
                                                    alwaysAllowManualTrigger ( true )
                                                    showPipelineParameters ( true )
                                                    showPipelineParametersInHeaders ( true )
                                                    startsWithParameters ( true ) // since 1.26
                                                    showPipelineDefinitionHeader( true )
                                                    refreshFrequency ( 30 )
                                                }            
                                            }
                                        }
                                    }
                                }
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

pipelineFilePrefix = GetPipelineFilePrefix ( curPipeline )
branchList = ParseBranchFile ( branchListFileName, pipelinePath, pipelineFilePrefix )
GenerateAllViews ( prodName, compName, branchList, branchSuffix )
