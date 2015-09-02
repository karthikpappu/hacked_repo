def c = { jobInfoList, project, baseJob, branchPath, branch = '' ->
    // --------------------------------------------------------------------------
	// generate the full name for the baseJob
	// to change the way full job names are calculated in your seed repo
	//  + create this file in your repo at src/jobdsl/closures/jobNamere.groovy  
	//  + keep the above parameters unchanged
	//  + modify the logic below to generate and return a string
	//  + the returned string will be used as the full job name for the baseJob
	// --------------------------------------------------------------------------
	def jobDef = jobInfoList[baseJob]
	def result = ''

	if ( jobDef ) {
		if ( jobDef['existing'] ) {
			result = baseJob
		} else {
			def branch_title = '-'
			if ( branchPath != '' ) {
				def matcher = branchPath =~ /^.*?\/(.*)\//
				if ( matcher ) {
					def rawBranchPath = matcher[0][1]
					switch ( rawBranchPath ) {
						case 'feature':
							branch_title += 'feat-'
							break
						case 'release':
							branch_title += 'rel-'
							break
						case 'hotfix':
							branch_title += 'hot-'
							break
					}
					logger.msginfo ( 'adding abbr. branch path to job name: ' + branch_title )
				}
			}
			if ( branch != '' ) {
				branch_title += branch + '-'
			}
			result = "${project.name}" + branch_title + baseJob
		}
	}

	result
}

