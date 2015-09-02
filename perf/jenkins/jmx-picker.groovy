def list = []


def sout = new StringBuffer()
def serr = new StringBuffer()

def command = "aws s3 ls --recursive s3://qbo-performance/jmeter"

def proc = command.execute()
proc.consumeProcessOutput(sout,serr)
proc.waitFor()

if ( ( proc.exitValue() != 0 )   || ( serr.length() != 0 )  ) {
  list.add('Problem with cli')
  list.add(serr.toString())
}
else {
  if (  sout.length() == 0 ) {
    list.add('Problem with S3 read')
  }
  else {
    index_string='jmeter/'
    for ( i in sout.toString().split("\n") ) {
      test_name = i.substring(i.indexOf(index_string) + index_string.size())
      list.add(test_name)
    }
  }
}
println list
return list
