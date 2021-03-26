#!/usr/bin/env cwl-runner
#
# Prediction file challenge workflow
# Inputs:
#   submissionId: ID of the Synapse submission to process
#   adminUploadSynId: ID of a folder accessible only to the submission queue administrator
#   submitterUploadSynId: ID of a folder accessible to the submitter
#   workflowSynapseId:  ID of the Synapse entity containing a reference to the workflow file(s)
#   synapseConfig: ~/.synapseConfig file that has your Synapse credentials
#
cwlVersion: v1.0
class: Workflow

requirements:
  - class: StepInputExpressionRequirement

inputs:
  - id: submissionId
    type: int
  - id: adminUploadSynId
    type: string
  - id: submitterUploadSynId
    type: string
  - id: workflowSynapseId
    type: string
  - id: synapseConfig
    type: File

# There are no output at the workflow engine level - everything is uploadeded to Synapse.
outputs: []

steps:

  download_submission:
    run: https://raw.githubusercontent.com/Sage-Bionetworks/ChallengeWorkflowTemplates/v3.1/cwl/get_submission.cwl
    in:
      - id: submissionid
        source: "#submissionId"
      - id: synapse_config
        source: "#synapseConfig"
    out:
      - id: filepath
      - id: docker_repository
      - id: docker_digest
      - id: entity_id
      - id: entity_type
      - id: results
      
  download_goldstandard:
    run: https://raw.githubusercontent.com/Sage-Bionetworks-Workflows/dockstore-tool-synapseclient/v1.3/cwl/synapse-get-tool.cwl
    in:
      - id: synapseid
        valueFrom: "syn18081597"  # TODO: replace with your own workflow SynapseID
      - id: synapse_config
        source: "#synapseConfig"
    out:
      - id: filepath

  validation:
    run: validate.cwl
    in:
      - id: inputfile
        source: "#download_submission/filepath"
      - id: entity_type
        source: "#download_submission/entity_type"
    out:
      - id: results
      - id: status
      - id: invalid_reasons
  
  validation_email:
    run: https://raw.githubusercontent.com/Sage-Bionetworks/ChallengeWorkflowTemplates/v3.1/cwl/validate_email.cwl
    in:
      - id: submissionid
        source: "#submissionId"
      - id: synapse_config
        source: "#synapseConfig"
      - id: status
        source: "#validation/status"
      - id: invalid_reasons
        source: "#validation/invalid_reasons"
      - id: errors_only  # remove this param if you would like to send "submission valid" emails as well.
        default: true

    out: [finished]

  annotate_validation_with_output:
    run: https://raw.githubusercontent.com/Sage-Bionetworks/ChallengeWorkflowTemplates/v3.1/cwl/annotate_submission.cwl
    in:
      - id: submissionid
        source: "#submissionId"
      - id: annotation_values
        source: "#validation/results"
      - id: to_public
        default: true
      - id: force
        default: true
      - id: synapse_config
        source: "#synapseConfig"
    out: [finished]

  check_status:
    run: https://raw.githubusercontent.com/Sage-Bionetworks/ChallengeWorkflowTemplates/v3.1/cwl/check_status.cwl
    in:
      - id: status
        source: "#validation/status"
      - id: previous_annotation_finished
        source: "#annotate_validation_with_output/finished"
      - id: previous_email_finished
        source: "#validation_email/finished"
    out: [finished]

  scoring:
    run: score.cwl
    in:
      - id: inputfile
        source: "#download_submission/filepath"
      - id: goldstandard
        source: "#download_goldstandard/filepath"
      - id: check_validation_finished 
        source: "#check_status/finished"
    out:
      - id: results
      
  score_email:
    run: https://raw.githubusercontent.com/Sage-Bionetworks/ChallengeWorkflowTemplates/v3.1/cwl/score_email.cwl
    in:
      - id: submissionid
        source: "#submissionId"
      - id: synapse_config
        source: "#synapseConfig"
      - id: results
        source: "#scoring/results"
      # - id: private_annotations
      #   default: []  # if there are scores that should not be returned to the participant, enter them here.
    out: []

  annotate_submission_with_output:
    run: https://raw.githubusercontent.com/Sage-Bionetworks/ChallengeWorkflowTemplates/v3.1/cwl/annotate_submission.cwl
    in:
      - id: submissionid
        source: "#submissionId"
      - id: annotation_values
        source: "#scoring/results"
      - id: to_public
        default: true
      - id: force
        default: true
      - id: synapse_config
        source: "#synapseConfig"
      - id: previous_annotation_finished
        source: "#annotate_validation_with_output/finished"
    out: [finished]
 