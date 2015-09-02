def c = {
	scm {
		git {
			remote {
				url ( jobContext.project.model.scm.git.repo ) // use either url or github
				credentials ( 'a3aacd77-ffdf-4f52-9b88-c67da55615c1' )
				// github(String ownerAndProject, String protocol = "https", String host = "github.com") // will also set the browser
																									     // and GitHub property
			}
			branches ( jobContext.branchPath + jobContext.branch ) // the branches to build, multiple calls are accumulated, defaults to **
			createTag ( true ) // create a tag for every build, optional, defaults to false
			wipeOutWorkspace ( true ) // wipe out workspace and force clone, optional, defaults to false
			cloneTimeout( 10 ) // since 1.28, timeout (in minutes) for clone and fetch operations
		}
	}
}
