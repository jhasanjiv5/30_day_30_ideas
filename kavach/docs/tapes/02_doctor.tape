Output "/tmp/vhs_02_doctor.gif"
Set Shell "bash"
Set FontSize 15
Set Width 1000
Set Height 560
Set Theme "Catppuccin Mocha"
Set Padding 20

Hide
Type "export DEMO_HOME=$(mktemp -d) && export HOME=$DEMO_HOME && export KAVACH_HOME=$DEMO_HOME/.kavach && kavach install --claude-code --user >/dev/null && clear"
Enter
Sleep 400ms
Show

Type "kavach doctor"
Enter
Sleep 800ms
Screenshot "docs/frames/02_doctor.png"
Sleep 300ms

Hide
Type "rm -rf $DEMO_HOME"
Enter
