def c = {
  if ( "${contact_email_or_dl}" != "" ) {
    publishers {
      mailer("${contact_email_or_dl}", false, true)
    }
  }
}
