Output "docs/frames/08_block_and_fix.gif"
Set Shell "bash"
Set FontSize 14
Set Width 1100
Set Height 540
Set Theme "Catppuccin Mocha"
Set Padding 20
Set TypingSpeed 35ms

Hide
Type "export DEMO_DIR=$(mktemp -d) && export KAVACH_HOME=$DEMO_DIR/.kavach && cd $DEMO_DIR && echo 'AWS_ACCESS_KEY_ID=AKIAIOSFODNN7EXAMPLE' > deploy.env && clear"
Enter
Sleep 400ms
Show

Type "# 1. Kavach blocks the secret before it reaches Claude"
Enter
Sleep 500ms
Type "kavach scan deploy.env"
Enter
Sleep 1800ms

Type "# 2. Redact with safe placeholder"
Enter
Sleep 500ms
Type "kavach scan --redact deploy.env > deploy.env.clean && cat deploy.env.clean"
Enter
Sleep 1600ms

Type "# 3. Verify clean scan"
Enter
Sleep 400ms
Type "kavach scan deploy.env.clean"
Enter
Sleep 1800ms

Hide
Type "rm -rf $DEMO_DIR"
Enter
