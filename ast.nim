import tokenQueue
import token
import types
import treeNode
import symbolTable
import std/strformat

proc getExpressionResultType(ltype:DataType, ntype:NodeType, rtype:DataType):DataType = 
    
    if not expressionToken(ntype.toTokenType()):
        raise newException(OSError, &"Invalid expression token: {ntype}")
    
    if ltype == Void or rtype == Void:
        raise newException(OSError, &"Operation {ntype} betewn {ltype} and {rtype} is invalid")

    case ntype
        of IntNode: return Int
        of CharNode: return Char
        of BoolNode: return Bool
        of  AddNode, SubtractNode, MultiplyNode, DivideNode:
            if ltype == Bool or rtype == Bool: raise newException(OSError, &"Operation {ntype} betewn {ltype} and {rtype} is invalid")
            elif ltype == rtype: return ltype
            elif ltype == Int or rtype == Int: return Int
            else: raise newException(OSError, &"Operation {ntype} betewn {ltype} and {rtype} is invalid")
        of EqualsNode, NotEqualsNode:
            if (ltype == Bool and rtype == Bool) or (ltype != Bool and rtype != Bool): return Bool
            else: raise newException(OSError, &"Operation {ntype} betewn {ltype} and {rtype} is invalid")
        of GreaterNode, LessNode, GreaterEqualsNode, LessEqualsNode:
            if ltype == Bool or rtype == Bool: raise newException(OSError, &"Operation {ntype} betewn {ltype} and {rtype} is invalid")
            elif ltype != Bool and rtype != Bool: return Bool
            else: raise newException(OSError, &"Operation {ntype} betewn {ltype} and {rtype} is invalid")
        else:
            raise newException(OSError, &"Operation {ntype} betewn {ltype} and {rtype} is invalid")

proc isNextToken(queue: TokenQueue, t: TokenType):bool = 
    var tk : Token = queue.peak()
    var tkType = tk.getType()
    return tkType == t

proc matchNextToken(queue: TokenQueue, t: TokenType) = 
    var tk : Token = queue.peak()
    var tkType = tk.getType()

    if tkType != t:
        raise newException(OSError,&"{t} expected but got {tkType}")

proc matchNextToken(queue: TokenQueue, t: seq[TokenType]) = 
    var tk : Token = queue.peak()
    var tkType = tk.getType()
    let r = tkType in t
    if not r:
        raise newException(OSError,&"{t} expected but got {tkType}")

proc compoundStatement(queue: var TokenQueue): TreeNode

proc parseExpression(queue: var TokenQueue, precedence: int = 0): TreeNode =  
    
    let tk = queue.dequeue()
    var nextType :TokenType = tk.getType()

    if not expressionToken(nextType):
        raise newException(OSError, &"Invalid expression token: {nextType}")

    if tk.getType() == TokenIdentifier and not existSymbol(tk.getIdentifier()):
        raise newException(OSError, &"Symbol not declared: {tk.getIdentifier()}")

    var lvalue : TreeNode = createNode(tk)
    nextType = queue.peak().getType()

    if expressionFinal(nextType):
        return lvalue
    
    if not expressionToken(nextType):
        raise newException(OSError, &"Invalid expression token: {nextType}")


    while nextType.getPrecedence() >= precedence:
        discard queue.dequeue()

        var rvalue: TreeNode = parseExpression(queue, nextType.getPrecedence())
        
        let ndType: NodeType = nextType.toNodeType()
        
        let lType = getExpressionResultType(lvalue.getDataType(),ndType,rvalue.getDataType())

        lvalue = createNode(ndType,lvalue,rvalue,lType)

        nextType = queue.peak().getType()

        if expressionFinal(nextType):
            return lvalue

    return lvalue

proc parseAssign(queue: var TokenQueue):TreeNode =
    let tk = queue.dequeue()

    if not existSymbol(tk.getIdentifier()):
        raise newException(OSError, &"Symbol not declared: {tk.getIdentifier()}")

    let lvalue : TreeNode = createNode(tk)

    matchNextToken(queue,TokenAssign)
    discard queue.dequeue() # discard =

    let rvalue = parseExpression(queue,0)

    if lvalue.getDataType() != rvalue.getDataType():
        raise newException(OSError, &"Can't assign {rvalue.getDataType()} to {lvalue.getDataType()}")

    return createNode(AsignNode,rvalue,lvalue)

proc parseVariableDeclaration(varType: DataType, varIdentifier: Token, queue: var TokenQueue): TreeNode =
    discard addSymbol(varIdentifier.getIdentifier(),Variable,varType)
    
    if isNextToken(queue, TokenSemiColonKeyword):
        return nil
    
    # declaration and asign

    discard queue.dequeue() # discard =
    
    let rvalue = parseExpression(queue,0)
    let lval = createNode(varIdentifier.getIdentifier())

    if lval.getDataType() != rvalue.getDataType():
        raise newException(OSError, &"Can't assign {rvalue.getDataType()} to {lval.getDataType()}")

    return createNode(AsignNode,rvalue,lval)

proc parseFunctionParams(queue: var TokenQueue) =
    
    while not isNextToken(queue, TokenRightParen):
        let typeDef = queue.dequeue().getType().getDataType() # get type 
        let identy = queue.dequeue() # get identifier
        
        discard addSymbol(identy.getIdentifier(),Variable,typeDef)

        if not isNextToken(queue, TokenComma):
            matchNextToken(queue, TokenRightParen)
        else:
            discard queue.dequeue() # discard ,

proc parseFunctionDeclaration(varType: DataType, varIdentifier: Token, queue: var TokenQueue): TreeNode =
    discard addSymbol(varIdentifier.getIdentifier(),Function,varType)


    matchNextToken(queue, TokenLeftParen)
    discard queue.dequeue()

    # parse function parameters
    parseFunctionParams(queue)
    
    matchNextToken(queue, TokenRightParen)
    discard queue.dequeue()
    
    let fnBody = compoundStatement(queue)
    return createNode(varIdentifier.getIdentifier(),fnBody)

proc parseDeclaration(queue: var TokenQueue):TreeNode =
    matchNextToken(queue,@[TokenIntType,TokenBoolType,TokenCharType,TokenVoidType])

    let typeDef = queue.dequeue().getType().getDataType() # get type 
    let identy = queue.dequeue() # get identifier
   
    # varibale declaration
    if isNextToken(queue,TokenAssign) or isNextToken(queue, TokenSemiColonKeyword):
        return parseVariableDeclaration(typeDef,identy,queue)
    
    # function declaration
    if isNextToken(queue,TokenLeftParen):
        return parseFunctionDeclaration(typeDef,identy,queue)

    return nil

proc parseIfStatement(queue: var TokenQueue): TreeNode =
    matchNextToken(queue,TokenIf)
    discard queue.dequeue() # discard if

    matchNextToken(queue,TokenLeftParen)
    discard queue.dequeue() # discard (

    let exp = parseExpression(queue)

    matchNextToken(queue,TokenRightParen)
    discard queue.dequeue() # discard )

    let whenTrue = compoundStatement(queue)
    var whenFalse: TreeNode = nil

    if isNextToken(queue,TokenElse):
        discard queue.dequeue() # discard else
        whenFalse = compoundStatement(queue)

    result = createNode(exp,whenTrue,whenFalse)

proc parseWhileStatement(queue: var TokenQueue): TreeNode =
    matchNextToken(queue,TokenWhile)
    discard queue.dequeue() # discard if

    matchNextToken(queue,TokenLeftParen)
    discard queue.dequeue() # discard (

    let exp = parseExpression(queue)

    matchNextToken(queue,TokenRightParen)
    discard queue.dequeue() # discard )

    let whenTrue = compoundStatement(queue)
   

    result = createNode(WhileNode, exp, whenTrue)

proc parseReturnStatement(queue: var TokenQueue): TreeNode =
    matchNextToken(queue,TokenReturn)
    discard queue.dequeue() # discard return

    let exp = parseExpression(queue, 0)
    let dt = exp.getDataType()
    if dt == Void or dt == None:
        raise newException(OSError,&"return type can not be {dt}")

    return createNode(ReturnNode, exp, dt)

proc parseStatement(queue: var TokenQueue): TreeNode =

    let tk : Token = queue.peak()

    let tkType = tk.getType();
    
    case tkType
    of TokenLeftBrace:
        return compoundStatement(queue)

    of TokenIntType,TokenBoolType,TokenCharType,TokenVoidType:
        let decl = parseDeclaration(queue)
        result = decl
        if isNextToken(queue,TokenSemiColonKeyword):
            discard queue.dequeue() # discard semicolon
    
    of TokenIdentifier:
        result = parseAssign(queue)
        matchNextToken(queue,TokenSemiColonKeyword)
        discard queue.dequeue() # discard semicolon
    of TokenIf:
        result = parseIfStatement(queue)
    of TokenWhile:
        result = parseWhileStatement(queue)
    of TokenReturn:
        result = parseReturnStatement(queue)
    else:
        raise newException(OSError, &"wrong program at {tk.getLine()}: {tkType}")

proc compoundStatement(queue: var TokenQueue): TreeNode = 
    matchNextToken(queue,TokenLeftBrace)
    discard queue.dequeue() # skip {
    
    var lastNode: TreeNode = nil
    var tmp: TreeNode
    var tkType = queue.peak().getType()
    
    while tkType != TokenRightBrace:
        
        if tkType == TokenEOF:
            raise newException(OSError, "Missing }")

        if tkType == TokenLeftBrace:
            tmp = compoundStatement(queue)
        else:
            tmp = parseStatement(queue)
        
        if tmp != nil:
            if lastNode != nil:
                lastNode = createGlueNode(lastNode,tmp)
            else:
                lastNode = tmp

        while isNextToken(queue,TokenSemiColonKeyword):
            discard queue.dequeue() # discard semicolon
        
        tkType = queue.peak().getType()
    
    matchNextToken(queue,TokenRightBrace)
    discard queue.dequeue() # skip }

    return createNode(CompoundNode,lastNode)

proc syntaxTree(queue: var TokenQueue): TreeNode =
    var lastNode: TreeNode = nil
    var tmp: TreeNode
    var tkType = queue.peak().getType()
    
    while tkType != TokenEOF:
        case tkType
            of TokenLeftBrace:
                tmp = compoundStatement(queue)
            of TokenIf:
                tmp = parseIfStatement(queue)
            of TokenWhile:
                tmp = parseWhileStatement(queue)
            else:
                tmp = parseStatement(queue)
        
        if tmp != nil:
            if lastNode != nil:
                lastNode = createGlueNode(lastNode,tmp)
            else:
                lastNode = tmp

        while isNextToken(queue,TokenSemiColonKeyword):
            discard queue.dequeue() # discard semicolon

        tkType = queue.peak().getType()


    return createNode(RootNode,lastNode)




export syntaxTree