job {

	def gitBranch = 'develop'
	
	def booleanDesc = """
	when this is checked, the job will only show you what jobs will be deleted<br>
    <b>UNCHECK THIS FLAG</b> when you are ready to actually delete the jobs<br>
	"""

	name ( "delete-${PRODUCT}-${COMPONENT}-${gitBranch}-pipeline" )
 
	logRotator( -1, 100, -1, 100 )
	
	parameters {
        choiceParam ( 'PRODUCT', [ "${PRODUCT}" ], '' )
        choiceParam ( 'COMPONENT', [ "${COMPONENT}" ], '' )
        choiceParam ( 'SOURCE_REPOSITORY', [ "${SOURCE_REPOSITORY}" ], '' )
        stringParam ( 'DEVELOP_BRANCH', gitBranch, '' )
        booleanParam ( 'DELETE_GIT_BRANCH', false, '' )
        booleanParam ( 'PREVIEW', true, booleanDesc )
	}

    label ( 'slingshot' )

	steps {
		conditionalSteps {
		    condition {
		        booleanCondition ( "\${DELETE_GIT_BRANCH}" ) // Run if the token evaluates to true.
		    }
		    runner( 'Run' ) // How to evaluate the results of a failure in the conditional step

			downstreamParameterized {		
				trigger ( 'delete-git-branch', 'ALWAYS', false,
							["buildStepFailure": "FAILURE",
							"failure": "FAILURE",
							"unstable": "UNSTABLE"] ) {

					predefinedProps ( [ "GIT_REPO" : "\${SOURCE_REPOSITORY}",
										"GIT_BRANCH_TO_DELETE" : gitBranch,
										"PREVIEW" : "\${PREVIEW}" ] )
				}
			}
		}

		downstreamParameterized {		
			trigger ( 'delete-jobs-by-regex', 'ALWAYS', false,
						["buildStepFailure": "FAILURE",
						"failure": "FAILURE",
						"unstable": "UNSTABLE"] ) {

				predefinedProps ( [ "regularExpression" : "\${PRODUCT}-\${COMPONENT}-${gitBranch}-.*",
									"preview" : "\${PREVIEW}" ] )									
			}
		}
		
		conditionalSteps {
		    condition {
		    	not {
		      	  booleanCondition ( "\${PREVIEW}" ) // Run if the token evaluates to true.
		      	}
		    }
		    runner( 'Run' ) // How to evaluate the results of a failure in the conditional step

			downstreamParameterized {		
				trigger ( 'slingshot-view-generator', 'ALWAYS', false,
							["buildStepFailure": "FAILURE",
							"failure": "FAILURE",
							"unstable": "UNSTABLE"] ) {

					predefinedProps ( [ "PRODUCT" : "\${PRODUCT}",
										"COMPONENT" : "\${COMPONENT}",
										"PIPELINE" : "java_app_${gitBranch}_workflow",
										"SOURCE_REPOSITORY" : "\${SOURCE_REPOSITORY}" ] )									
				}
			}
		}
	}
}
