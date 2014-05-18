{-# LANGUAGE OverloadedStrings, Rank2Types, FlexibleContexts, FlexibleInstances #-}
module Scheme.Types
    ( LispVal(..)
    , Fix(..)
    , LispError(..)
    , LispEnv()
    , ThrowsError

--    , liftThrows
--    , runIOThrows
    ) where

import Control.Monad
import Control.Monad.ST
import Data.STRef
import System.IO
import Text.Parsec (ParseError)
import qualified Data.Text as T

-- Fix
newtype Fix f = Fix (f (Fix f))

-- Scheme AST
data LispVal ref = Atom T.Text
                 | List [LispVal ref]
                 | DottedList [LispVal ref] (LispVal ref)
                 | Number Integer
                 | String T.Text
                 | Bool Bool
                 | PrimitiveFunc ([LispVal ref] -> ThrowsError (LispVal ref))
                 | Func { params :: [T.Text]
                        , vararg :: Maybe T.Text
                        , body :: [LispVal ref]
                        , closure :: ref
                        }

instance Show (LispVal ref) where
    show = T.unpack . showVal

instance Show (Fix LispVal) where
    show (Fix v) = T.unpack $ showVal v

showVal :: LispVal s -> T.Text
showVal (String contents) = T.concat ["\"", contents, "\""]
showVal (Atom name) = name
showVal (Number contents) = T.pack $ show contents
showVal (Bool True) = "#t"
showVal (Bool False) = "#f"
showVal (List contents) = T.concat ["(", unwordsList contents, ")"]
showVal (DottedList head tail) = T.concat ["(", unwordsList head, " . ", showVal tail, ")"]
showVal (PrimitiveFunc _) = "<primitive>"
showVal (Func {params = args, vararg = varargs, body = body, closure = env}) = T.concat
    [ "(lambda ("
    , T.unwords (map (T.pack . show) args)
    , case varargs of
        Nothing -> ""
        Just arg -> T.concat [" . ", arg]
    , ") ...)"
    ]

unwordsList :: [LispVal s] -> T.Text
unwordsList = T.unwords . map showVal


-- Scheme Error reporting
data LispError = NumArgs Integer [Fix LispVal]
               | TypeMismatch T.Text (Fix LispVal)
               | Parser ParseError
               | BadSpecialForm T.Text (Fix LispVal)
               | NotFunction T.Text T.Text
               | UnboundVar T.Text T.Text
               | Default T.Text

instance Show LispError where
    show = T.unpack . showError

type ThrowsError = Either LispError

showError :: LispError -> T.Text
showError (NumArgs expected found)      = T.concat ["Expected ", (T.pack . show) expected, " args; found values ", unwordsFixList found]
showError (TypeMismatch expected found) = T.concat ["Invalid type: expected ", expected, ", found ", (T.pack . show) found]
showError (Parser parseErr)             = T.concat ["Parse error at ", (T.pack . show) parseErr]
showError (BadSpecialForm message form) = T.concat [message, ": ", (T.pack . show) form]
showError (UnboundVar message varname)  = T.concat [message, ": ", varname]
showError (NotFunction message func)    = T.concat [message, ": ", func]

unwordsFixList :: [Fix LispVal] -> T.Text
unwordsFixList = T.unwords . map (T.pack . show)


-- Scheme Execution Environment
type LispEnv s = STRef s [(T.Text, STRef s (LispVal s))]


---- TODO: not sure this is best spot
--liftThrows :: ThrowsError s a -> IOThrowsError s a
--liftThrows (Left err) = throwError err
--liftThrows (Right val) = return val
--
---- TODO: not sure this is best spot, update to toss Text
--runIOThrows :: IOThrowsError s T.Text -> IO T.Text
--runIOThrows action = liftM extractValue $ runErrorT (trapError action)
--
--trapError :: (Show e, MonadError e m) => m T.Text -> m T.Text
--trapError action = catchError action (return . T.pack . show)
--
---- TODO: incomplete
--extractValue :: ThrowsError s a -> a
--extractValue (Right val) = val
