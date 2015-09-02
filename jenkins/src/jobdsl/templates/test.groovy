// Dummy test Template //

job(type: "Maven") {
    label('slingshot')
    jdk('JDK1.8')
    _snip('scm', delegate)
	
  	// Build trigger interval  
    	triggers {
            scm('00 20 * * *')
        }
    
  	// Maven options
    	rootPOM('app/pom.xml')
    	goals('clean')
    	mavenOpts('-Xmx512m -XX:MaxPermSize=256m')
    	mavenInstallation('Maven_3.0.5')
}

