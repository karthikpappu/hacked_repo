//STATIC CODE  JOB TEMPLATE //

job(type: "Maven") {

	disabled(false)
    jdk('JDK1.8')
    // jdk("${JDK_VERSION}")
      	_snip('scm', delegate)

  	// Build trigger interval  
    	triggers {
            scm('00 20 * * *')
        }
	
	// Remote build trigger using authentication token.  
         configure {
                (it / 'authToken').setValue('build')
        }
    
  	// Maven options
    	rootPOM('pom.xml')
    	goals('-U -Dmaven.local.repo=/app/mavenRepo -Pclover install clover2:clover site')
    	mavenOpts('-Xmx512m -XX:MaxPermSize=256m -XX:+CMSClassUnloadingEnabled')
    	mavenInstallation('Maven_3.0.5') // since 1.20
    	archivingDisabled(true)
    	configure { 
            (it / 'siteArchivingDisabled').setValue('true') 
        }
	
 	//  Following configure block is for publishing testng report
 	configure { node ->
        	node / publishers << 'hudson.plugins.testng.Publisher' {
                reportFilenamePattern('target/site/surefire-report.html')
                escapeTestDescp(true)
                escapeExceptionMsg(true)
                showFailedBuilds(false)
                unstableOnSkippedTests(false)
        	}
    	}
		
	// Following configure block is for publishing clover report
 	configure { node ->
                node / publishers << 'hudson.plugins.clover.CloverPublisher' {
                cloverReportDir('target/site/clover')
                cloverReportFileName('clover.xml')
                        'healthyTarget' {
                                methodCoverage('70')
                                conditionalCoverage('80')
                                statementCoverage('80')
                        }
                unhealthyTarget('')
                failingTarget('')
                }
        }

	// Following configure block is for publishing findbug report 
	configure { node ->
                node / reporters << 'hudson.plugins.findbugs.FindBugsReporter' {
		healthy('')
      		unHealthy('')
      		pluginName('[FINDBUGS] ')
      		thresholdLimit('low')
      		canRunOnFailed(false)
      		useDeltaValues(false)
      			'thresholds' {
        			unstableTotalAll('')
        			unstableTotalHigh('')
        			unstableTotalNormal('')
        			unstableTotalLow('')
        			failedTotalAll('')
        			failedTotalHigh('')
        			failedTotalNormal('')
        			failedTotalLow('')
			}
      		dontComputeNew(true)
      		usePreviousBuildAsReference(false)
      		useStableBuildAsReference(false)
      		isRankActivated(false)
      		excludePattern('')
      		includePattern('')
                	
        	}
	}

	// Following configure block is for publishing checkstyle report
	configure { node ->
                node / reporters << 'hudson.plugins.checkstyle.CheckStyleReporter' {
                healthy('')
                unHealthy('')
                pluginName('[CHECKSTYLE] ')
                thresholdLimit('low')
                canRunOnFailed(false)
                useDeltaValues(false)
                        'thresholds' {
                                unstableTotalAll('')
                                unstableTotalHigh('')
                                unstableTotalNormal('')
                                unstableTotalLow('')
                                failedTotalAll('')
                                failedTotalHigh('')
                                failedTotalNormal('')
                                failedTotalLow('')
			}
                dontComputeNew(true)
                usePreviousBuildAsReference(false)
                useStableBuildAsReference(false)
                }
        }
	
	// Following configure block is for publishing pmd report
	configure { node ->
                node / reporters << 'hudson.plugins.pmd.PmdReporter' {
                healthy('')
                unHealthy('')
                pluginName('[PMD] ')
                thresholdLimit('low')
                canRunOnFailed(false)
                useDeltaValues(false)
                        'thresholds' {
                                unstableTotalAll('')
                                unstableTotalHigh('')
                                unstableTotalNormal('')
                                unstableTotalLow('')
                                failedTotalAll('')
                                failedTotalHigh('')
                                failedTotalNormal('')
                 	}      
	        failedTotalLow('')
                dontComputeNew(true)
                usePreviousBuildAsReference(false)
                useStableBuildAsReference(false)
                        
                }
        }
        
	// Downstream and reporting
    // publishers {
    //          extendedEmail("${EMAIL_TO}")
    // }
}

