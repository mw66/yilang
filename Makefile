
all: yc

DUB=dub

yc: source/*.d
	$(DUB) build

clean:
	$(DUB) clean

