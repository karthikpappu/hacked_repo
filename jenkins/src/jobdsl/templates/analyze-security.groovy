// SECURITY JOB TEMPLATE //

job(type: "Maven") {
	disabled(false)
    label('slingshot')
	jdk('JDK1.8')
    // jdk("${JDK_VERSION}")
    _snip('scm', delegate)
	
    wrappers {
       environmentVariables {
	       env('PATH', '$PATH:/opt/fortify/bin')
         }
    }

  	// Build trigger interval  
    	triggers {
            scm('00 20 * * *')
        }
    
  	// Maven options
    	rootPOM('app/pom.xml')
    	goals('-U -Dmaven.repo.local=/app/mavenRepo -DskipTests clean install -Pfortify')
    	mavenOpts('-Xmx512m -XX:MaxPermSize=256m -XX:+CMSClassUnloadingEnabled')
    	mavenInstallation('Maven_3.0.5') // since 1.20
    	archivingDisabled(true)
    	configure { 
            (it / 'siteArchivingDisabled').setValue('true') 
        }

  	// Downstream and reporting
    // publishers { 
    //  extendedEmail("${EMAIL_TO}")
	// }

    // Publish Fortify   
	configure { node ->
                node / publishers << 'org.jvnet.hudson.plugins.fortify360.FPRPublisher' {
                fpr('')
                filterSet('')
                searchCondition('')
                f360projId('75790873')
                auditToken('')
                auditScript('')
                }
        }

}

