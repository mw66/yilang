
all: yc

DUB=dub

yc: source/*.d
	$(DUB) -q build

example:
	./yc -c test/visitor.yi

clean:
	$(DUB) clean

# if needed to change account:
# git config --global -e
push:
	git config --global --list
	git push https://'yilabs'@github.com/yilabs/yilang.git
