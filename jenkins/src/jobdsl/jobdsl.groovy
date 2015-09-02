import com.intuit.tools.devops.workflow.jenkins.*

// Establish an initial context, supplying reference to "this" script
// and the working directory
def pipelineContext = new PipelineContext(this,
	"${JOBDSL_ROOTDIR}")

// Create the initial toolkit
def toolkit = DefaultJobDslToolkitFactory.create(pipelineContext)

// Get the pipeline builder and create the flows
def pipelineBuilder = toolkit.getPipelineBuilder()
pipelineBuilder.createAllWorkFlows()
