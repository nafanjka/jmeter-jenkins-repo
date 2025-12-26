pipeline {
  agent any
  options { timestamps() }
  parameters {
    string(name: 'TEST', defaultValue: 'tests/Test_Plan.jmx', description: 'Single JMX file to run (relative to workspace root or absolute).')
    string(name: 'ENDPOINT', defaultValue: 'https://localhost:8000', description: 'Target endpoint URL (protocol://host:port).')
    booleanParam(name: 'HTML_REPORT', defaultValue: true, description: 'Generate and publish the JMeter HTML report')

    string(name: 'THREADS', defaultValue: '', description: 'Optional: -Jthreads value')
    string(name: 'DURATION', defaultValue: '', description: 'Optional: -Jduration (seconds)')
    string(name: 'RAMP_UP', defaultValue: '', description: 'Optional: -Jrampup (seconds)')
    string(name: 'LOOP_COUNT', defaultValue: '', description: 'Optional: -Jloopcount')
  }
  environment {
    RESULTS_ROOT = 'results'
  }
  stages {
    stage('Prepare') {
      steps {
        sh 'mkdir -p results'
        sh 'chmod +x scripts/run-jmeter.sh'
        sh 'echo "Workspace: $(pwd)"'
      }
    }
    stage('Select Test') {
      steps {
        script {
          def provided = params.TEST?.trim()
          if (provided) {
            env.TEST = provided
            echo "Using TEST parameter: ${env.TEST}"
          } else {
            error 'TEST parameter is required; no interactive selection is available.'
          }
        }
      }
    }
    stage('Run JMeter') {
      steps {
        sh label: 'Execute JMeter', script: '''
          export TEST="${TEST}"
          export RESULTS_ROOT="${RESULTS_ROOT}"
          export ENDPOINT="${ENDPOINT}"
          export THREADS="${THREADS}"
          export DURATION="${DURATION}"
          export RAMP_UP="${RAMP_UP}"
          export LOOP_COUNT="${LOOP_COUNT}"
          export HTML_REPORT="${HTML_REPORT}"
          jmx="${TEST}"
          if [ -z "$jmx" ]; then
            echo "No TEST provided. Set the TEST parameter to a JMX file."
            exit 1
          fi

          echo "Running JMeter for: $jmx"
          export JMX_PATH="$jmx"
          scripts/run-jmeter.sh
        '''
      }
    }
    stage('Archive Artifacts') {
      steps {
        script {
          // Archive everything in results, including HTML report
          archiveArtifacts artifacts: 'results/**', fingerprint: true, allowEmptyArchive: false
        }
      }
    }
    stage('Publish HTML Report') {
      steps {
        script {
          // Publish the latest report folder if present and enabled
          if (params.HTML_REPORT) {
            def latest = sh(script: 'ls -1dt results/*/report 2>/dev/null | head -n1', returnStdout: true).trim()
            if (latest) {
              publishHTML(target: [
                allowMissing: true,
                keepAll: true,
                alwaysLinkToLastBuild: true,
                reportDir: latest,
                reportFiles: 'index.html',
                reportName: 'JMeter HTML Report'
              ])
            } else {
              echo 'No HTML report directory found to publish.'
            }
          } else {
            echo 'HTML report publishing disabled by parameter.'
          }
        }
      }
    }
  }
  post {
    always {
      cleanWs deleteDirs: false, notFailBuild: true
    }
  }
}
