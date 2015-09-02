# DRAFT Contributing

Here's a quick guide.


Clone repo
    git clone git@github.intuit.com:<ORG>/<repo>.git
    
Add upstream repo

    git checkout master
    git remote add upstream git@github.intuit.com:SBG-TAC/TAC_AWS_Platform.git
    
merge latest code from upstream 

    git pull upstream master
    resolve any conflicts
        use git status to determine which files need to be merged (search in file for =====)

commit code to your repo

    git commit -m "merge upstream/master and resolve merge conflicts"
    git push origin master
    confirm by running
        git status


Push code to slingshot core
merge latest code from upstream
    git checkout -b upstream upstream/master
    git cherry-pick <SHA hash of commit>
    git merge upstream/master
    git push origin upstream
    
    submit pull request ?? or if you have commit acesss
    git push upstream master


At this point you're waiting on us. We like to at least comment on pull requests
within three business days (and, typically, one business day). We may suggest
some changes or improvements or alternatives.

Some things that will increase the chance that your pull request is accepted:

* Write tests.
* Follow our [style guide][style].
* Write a [good commit message][commit].

[style]: https://github.com/thoughtbot/guides/tree/master/style
[commit]: http://tbaggery.com/2008/04/19/a-note-about-git-commit-messages.html
