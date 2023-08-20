import token
import std/strformat

type TokenQueue = object 
    values : seq[Token]
    index: int

proc initTokenQueue(tokenList: seq[Token]): TokenQueue =
    result.index = 0
    result.values = tokenList

proc empty(self: TokenQueue): bool = self.values.len <= self.index

proc enqueue(self: var TokenQueue, token: Token) = self.values.add(token)

proc dequeue(self: var TokenQueue): Token =
    if not self.empty():
        result = self.values[self.index]
        self.index += 1
    else:
        raise newException(OSError,"Token queue is empty")


proc peak(self: TokenQueue): Token =
    if not self.empty():
        return self.values[self.index]
    else:
        raise newException(OSError,"Token queue is empty")
   

proc toFile(self: TokenQueue, name: string) = 
    var queueFile: File
    discard open(queueFile, "queue.txt", fmWrite)

    for t in self.values:
        queueFile.write(&"{t}\n")

    close(queueFile)

export TokenQueue, initTokenQueue,enqueue,dequeue,peak,empty,toFile