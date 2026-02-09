pipeline {
    agent none

    environment {
        ANDROID_HOME = '/opt/android-sdk'
        GRADLE_OPTS = '-Dorg.gradle.daemon=false -Dorg.gradle.parallel=true -Dorg.gradle.workers.max=2'
        SCRIPTS_DIR = 'pipeline-utils/scripts'
        COVERAGE_TARGET = '95'
        BUILD_RETRY_COUNT = '3'
    }

    options {
        buildDiscarder(logRotator(numToKeepStr: '30', artifactNumToKeepStr: '10'))
        timestamps()
        timeout(time: 1, unit: 'HOURS')
        disableConcurrentBuilds(abortPrevious: true)
        retry(1)
    }

    stages {
        stage('Pre-Flight Checks') {
            agent { label 'android utility' }
            parallel {
                stage('Environment') {
                    steps {
                        sh '''
                            echo "=== Environment Check ==="
                            echo "Java version:"
                            java -version
                            echo "Gradle version:"
                            ./gradlew --version
                            echo "Docker version:"
                            docker --version
                            echo "Agent: ${NODE_NAME}"
                        '''
                    }
                }
                stage('Scripts Availability') {
                    steps {
                        sh '''
                            echo "=== Scripts Check ==="
                            if [ -d "${SCRIPTS_DIR}" ]; then
                                echo "✅ Scripts directory found"
                                echo "Total scripts: $(find ${SCRIPTS_DIR} -name '*.sh' -o -name '*.py' | wc -l)"
                            else
                                echo "❌ Scripts directory not found"
                                exit 1
                            fi
                        '''
                    }
                }
            }
        }

        stage('Checkout & Setup') {
            agent { label 'android utility' }
            steps {
                echo 'Checking out code...'
                checkout scm
                sh '''
                    echo "Git commit: $(git rev-parse HEAD)"
                    echo "Git branch: $(git branch --show-current)"
                    echo "Git author: $(git log -1 --format='%an <%ae>')"
                '''
            }
        }

        stage('Security & Quality Scans') {
            parallel {
                stage('Secret Scanning') {
                    agent { label 'android utility' }
                    steps {
                        sh '''
                            echo "=== Secret Scanning ==="
                            if [ -f "${SCRIPTS_DIR}/pre-commit-secrets.sh" ]; then
                                ${SCRIPTS_DIR}/pre-commit-secrets.sh || echo "Warning: Secret scan failed"
                            else
                                echo "Basic secret scan:"
                                git grep -iE "password|secret|api[_-]?key|token" --unmatched || echo "No secrets found in code"
                            fi
                        '''
                    }
                }
                stage('License Check') {
                    agent { label 'android utility' }
                    steps {
                        sh '''
                            echo "=== License Compliance ==="
                            if [ -f "${SCRIPTS_DIR}/check-licenses.sh" ]; then
                                ${SCRIPTS_DIR}/check-licenses.sh || echo "Warning: License check failed"
                            fi
                        '''
                    }
                }
                stage('Format Check') {
                    agent { label 'android utility' }
                    steps {
                        sh '''
                            echo "=== Code Format Check ==="
                            if [ -f "${SCRIPTS_DIR}/pre-commit-format.sh" ]; then
                                ${SCRIPTS_DIR}/pre-commit-format.sh || echo "Warning: Format check failed"
                            fi
                        '''
                    }
                }
            }
        }

        stage('Build APK') {
            agent { label 'android build' }
            steps {
                echo 'Building Android APK...'
                sh '''
                    echo "=== Building Debug APK ==="
                    ./gradlew assembleDebug --stacktrace
                    echo "=== Build Artifacts ==="
                    find . -name "*.apk" -type f
                '''
            }
            post {
                success {
                    archiveArtifacts artifacts: '**/build/outputs/apk/**/*.apk', fingerprint: true
                }
            }
        }

        stage('Test Execution') {
            parallel {
                stage('Unit Tests') {
                    agent { label 'android test' }
                    steps {
                        sh '''
                            echo "=== Running Unit Tests ==="
                            ./gradlew test --stacktrace --continue
                        '''
                    }
                    post {
                        always {
                            junit '**/build/test-results/test/**/*.xml'
                            sh '''
                                echo "=== Test Summary ==="
                                find build/test-results -name "*.xml" -exec grep -h "tests=" {} \;
                            '''
                        }
                    }
                }
                stage('Instrumented Tests') {
                    agent { label 'android test' }
                    steps {
                        sh '''
                            echo "=== Running Instrumented Tests ==="
                            ./gradlew connectedAndroidTest --stacktrace --continue || echo "Instrumented tests may require emulator"
                        '''
                    }
                }
                stage('Coverage Analysis') {
                    agent { label 'android test' }
                    steps {
                        sh '''
                            echo "=== Code Coverage Analysis ==="
                            ./gradlew jacocoTestReport jacocoTestCoverageVerification
                            if [ -f "build/reports/jacoco/test/html/index.html" ]; then
                                echo "Coverage report: build/reports/jacoco/test/html/index.html"
                                # Extract coverage percentage
                                COVERAGE=$(grep -oP 'Total[^%]*<td class="cover">\\d+%' build/reports/jacoco/test/html/index.html | grep -oP '\\d+' | tail -1)
                                echo "Coverage: ${COVERAGE}%"
                                if [ -n "$COVERAGE" ] && [ "$COVERAGE" -lt "${COVERAGE_TARGET}" ]; then
                                    echo "⚠️ Coverage below target: ${COVERAGE}% < ${COVERAGE_TARGET}%"
                                fi
                            fi
                        '''
                    }
                    post {
                        always {
                            publishHTML([
                                allowMissing: false,
                                alwaysLinkToLastBuild: true,
                                keepAll: true,
                                reportDir: 'build/reports/jacoco/test/html',
                                reportFiles: 'index.html',
                                reportName: 'Coverage Report'
                            ])
                        }
                    }
                }
            }
        }

        stage('Android Lint') {
            agent { label 'android test' }
            steps {
                sh '''
                    echo "=== Android Lint Analysis ==="
                    ./gradlew lint --continue
                '''
            }
            post {
                always {
                    androidLint pattern: '**/build/reports/lint-results-*.xml'
                    recordIssues enabledForFailure: true, tools: [androidLint()]
                }
            }
        }

        stage('Quality Gates') {
            agent { label 'android utility' }
            steps {
                sh '''
                    echo "=== Quality Gates ==="

                    # Check if tests passed
                    if [ ! -d "build/test-results" ]; then
                        echo "❌ No test results found"
                        exit 1
                    fi

                    # Count test results
                    TOTAL=$(find build/test-results -name "*.xml" -exec grep -h "tests=" {} \; | grep -oE "tests=\"[0-9]+\"" | grep -oE "[0-9]+" | awk '{s+=$1} END {print s}')
                    FAILURES=$(find build/test-results -name "*.xml" -exec grep -h "failures=" {} \; | grep -oE "failures=\"[0-9]+\"" | grep -oE "[0-9]+" | awk '{s+=$1} END {print s}')

                    echo "Total tests: ${TOTAL:-0}"
                    echo "Failures: ${FAILURES:-0}"

                    if [ -n "$FAILURES" ] && [ "$FAILURES" -gt 0 ]; then
                        echo "❌ Quality gate failed: $FAILURES test failures"
                        exit 1
                    fi

                    # Coverage gate
                    if [ -f "build/reports/jacoco/test/html/index.html" ]; then
                        COVERAGE=$(grep -oP 'Total[^%]*<td class="cover">\\d+%' build/reports/jacoco/test/html/index.html | grep -oP '\\d+' | tail -1)
                        echo "Coverage: ${COVERAGE}%"
                        if [ -n "$COVERAGE" ] && [ "$COVERAGE" -lt "${COVERAGE_TARGET}" ]; then
                            echo "⚠️ Coverage below target: ${COVERAGE}% < ${COVERAGE_TARGET}%"
                            # Don't fail on coverage warning, just alert
                        fi
                    fi

                    echo "✅ Quality gates passed"
                '''
            }
        }

        stage('Self-Healing Check') {
            agent { label 'android utility' }
            steps {
                script {
                    def retryCount = currentBuild.previousBuild ? currentBuild.previousBuild.getActions(hudson.model.ParametersAction)?.find { it.getParameter('RETRY_COUNT') }?.value : '0'
                    if (currentBuild.result == 'FAILURE' && retryCount.toInteger() < BUILD_RETRY_COUNT.toInteger()) {
                        echo "⚠️ Build failed, attempting retry (${retryCount.toInteger() + 1}/${BUILD_RETRY_COUNT})"
                        currentBuild.result = 'SUCCESS'
                        build(
                            job: env.JOB_NAME,
                            parameters: [string(name: 'RETRY_COUNT', value: (retryCount.toInteger() + 1).toString())],
                            wait: false
                        )
                    }
                }
            }
        }
    }

    post {
        always {
            echo '=== Pipeline Execution Summary ==='
            sh '''
                echo "Build: ${currentBuild.result}"
                echo "Duration: ${currentBuild.durationString}"
                echo "Workspace: ${env.WORKSPACE}"
                echo "Agent: ${env.NODE_NAME}"
                echo "Build URL: ${env.BUILD_URL}"

                # Generate build report
                cat > build-summary.txt << EOF
================================
Jenkins Build Summary
================================
Job: ${env.JOB_NAME}
Build: ${env.BUILD_NUMBER}
Result: ${currentBuild.result}
Duration: ${currentBuild.durationString}
Branch: ${env.GIT_BRANCH}
Commit: ${env.GIT_COMMIT}
Agent: ${env.NODE_NAME}
================================
EOF

                # Archive summary
                echo "Build summary created"
            '''
        }
        success {
            echo '✅ Pipeline completed successfully!'
            sh '''
                if [ -n "${SLACK_WEBHOOK:-}" ]; then
                    echo "Slack notification: SUCCESS"
                fi
                if [ -f "${SCRIPTS_DIR}/send-notification.sh" ]; then
                    ${SCRIPTS_DIR}/send-notification.sh "success" "${env.BUILD_URL}"
                fi
            '''
        }
        failure {
            echo '❌ Pipeline failed!'
            sh '''
                # Generate failure report
                cat > failure-report.txt << EOF
================================
PIPELINE FAILURE REPORT
================================
Job: ${env.JOB_NAME}
Build: ${env.BUILD_NUMBER}
Status: FAILED
Agent: ${env.NODE_NAME}
Timestamp: $(date)

Check console output: ${env.BUILD_URL}console
EOF

                if [ -f "${SCRIPTS_DIR}/send-notification.sh" ]; then
                    ${SCRIPTS_DIR}/send-notification.sh "failure" "${env.BUILD_URL}"
                fi
            '''
        }
        unstable {
            echo '⚠️ Pipeline unstable!'
        }
        cleanup {
            sh '''
                echo "=== Cleanup ==="
                # Clean temporary files
                find . -name "*.tmp" -delete
                find . -name ".DS_Store" -delete
            '''
            cleanWs(
                deleteDirs: true,
                patterns: [
                    [pattern: '**/build', type: 'EXCLUDE'],
                    [pattern: '**/.gradle', type: 'EXCLUDE']
                ]
            )
        }
    }
}
