job {

	name ( 'clone-github-repo' )

	logRotator( -1, 100, -1, 100 )

	parameters {

		// CJB!!
		// May need to replace the entire parameter block with a configure block
		// in order to create a password parameter
		//
        stringParam ( 'API', '333d8282b5b1c611b08e77c01430d631ed977f4e' , '' )
        stringParam ( 'source_repo', 'SBG-TAC/TAC_AWS_Platform', '' )
        stringParam ( 'source_repo_branch', 'master', '' )
        stringParam ( 'dest_repo_branch', '\${source_repo_branch}', '' )
        stringParam ( 'dest_repo', 'SBG/test_app', '' )
        stringParam ( 'desc', "clone of \${source_repo}", '' )
        choiceParam ( 'gist_repo', [ 'git@github.intuit.com:gist/dbdd169b27466fa7b6ee.git' ], '' )
	}

	// CJB!!
	// probably should have a way to automate adding a node to the Jenkins server
	// and give it the label 'slingshot'
	//
	label ( 'slingshot' )

	scm {
		git {
			remote {
				url ( 'git@github.intuit.com:${source_repo}.git' ) // use either url or github
				// CJB!!
				// These credentials will need to be set up separately (and renamed if not set up the same way)
				//
				credentials ( 'scmbuild@all-jenkins-slaves' )
			}
			branches ( '*/${source_repo_branch}' ) // the branches to build, multiple calls are accumulated, defaults to **
			createTag ( true ) // create a tag for every build, optional, defaults to false
			wipeOutWorkspace ( true ) // wipe out workspace and force clone, optional, defaults to false
		}
	}

	wrappers {
		preBuildCleanup ( )
	}

	steps {
		shell (
"""
track_repo () {
  cd \${WORKSPACE}
  git clone \${gist_repo} \${source_base_repo}.clone.list
  cd \${source_base_repo}.clone.list
  if ! grep -q -F "\${dest_repo}" \${source_base_repo}.clone.list.txt ; then
    echo "\${dest_repo}" >> \${source_base_repo}.clone.list.txt
    git add ./\${source_base_repo}.clone.list.txt
    git commit -m "adding \${dest_repo}" ./\${source_base_repo}.clone.list.txt
    git push origin master
  fi
}

dest_org=\$(dirname \${dest_repo})
dest_base_repo=\$(basename \${dest_repo})
source_base_repo=\$(basename \${source_repo})

curl -s -u \${API}:x-oauth-basic --request POST --data "{\\"name\\" : \\"\${dest_base_repo}\\", \\"description\\" : \\"\${desc}\\"}"  --url "https://github.intuit.com/api/v3/orgs/\${dest_org}/repos"

git remote add new_repo git@github.intuit.com:\${dest_repo}.git
git checkout \${source_repo_branch}
git pull origin \${source_repo_branch}
git push -u new_repo \${source_repo_branch}:\${dest_repo_branch}

if [[ "\${source_repo}" == "SBG-TAC/TAC_AWS_Platform" ]]; then
  track_repo
fi
"""
		)
	}
}
