Output "/tmp/vhs_01_install.gif"
Set Shell "bash"
Set FontSize 15
Set Width 1000
Set Height 520
Set Theme "Catppuccin Mocha"
Set Padding 20

Hide
Type "export DEMO_HOME=$(mktemp -d) && export HOME=$DEMO_HOME && export KAVACH_HOME=$DEMO_HOME/.kavach && clear"
Enter
Sleep 400ms
Show

Type "kavach install --claude-code --user"
Enter
Sleep 800ms
Screenshot "docs/frames/01_install.png"
Sleep 300ms

Hide
Type "rm -rf $DEMO_HOME"
Enter
