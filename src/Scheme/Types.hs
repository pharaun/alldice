{-# LANGUAGE OverloadedStrings, Rank2Types, FlexibleContexts, FlexibleInstances #-}
module Scheme.Types
    ( LispVal(..)
    , LispError(..)
    , LispEnv()
    , ThrowsError
    , expand
    , Fix(..)

--    , liftThrows
--    , runIOThrows
    ) where

import Control.Monad.ST
import Data.STRef
import Text.Parsec (ParseError)
import qualified Data.Text as T

-- Not ideal but should in theory work for now
import System.Random

-- Fix
newtype Fix f = Fix (f (Fix f))

-- TODO: trivial expander we terminate early
-- TODO: Need to have a unexpand version so that we can have the parser
-- spit out (Fix LispVal) then unexpand it into ST (if this makes any sense at all)
expand :: LispVal s -> Fix LispVal
expand (Atom name)              = Fix (Atom name)
expand (List contents)          = Fix (List [String $ T.concat ["<TODO List> - ", T.pack $ show (map expand contents)]])
expand (DottedList _ _)         = Fix (DottedList [String "<TODO Dotted>"] (String "<TODO Dotted 2>"))
expand (Number contents)        = Fix (Number contents)
expand (Random contents)        = Fix (Random contents)
expand (String contents)        = Fix (String contents)
expand (Bool bool)              = Fix (Bool bool)
expand (PrimitiveFunc _)        = Fix (String "<primitive>")
expand (StatefulFunc _)         = Fix (String "<ST primitive>")
expand (Func {})                = Fix (String "<Function>")

-- Scheme AST
data LispVal ref = Atom T.Text
                 | List [LispVal ref]
                 | DottedList [LispVal ref] (LispVal ref)
                 | Number Integer
                 | Random StdGen -- TODO: not sure this is the best approach
                 | String T.Text
                 | Bool Bool
                 | PrimitiveFunc ([LispVal ref] -> ThrowsError (LispVal ref))
                 | StatefulFunc ([LispVal ref] -> ST ref (ThrowsError (LispVal ref))) -- TODO: not needed as far as i can tell
                 | Func { params :: [T.Text]
                        , vararg :: Maybe T.Text
                        , body :: [LispVal ref]
                        , closure :: LispEnv ref
                        }

instance Show (LispVal ref) where
    show = T.unpack . showVal

instance Show (Fix LispVal) where
    show (Fix v) = T.unpack $ showVal v

showVal :: LispVal s -> T.Text
showVal (String contents) = T.concat ["\"", contents, "\""]
showVal (Atom name) = name
showVal (Number contents) = T.pack $ show contents
showVal (Random contents) = T.pack $ show contents
showVal (Bool True) = "#t"
showVal (Bool False) = "#f"
showVal (List contents) = T.concat ["(", unwordsList contents, ")"]
showVal (DottedList head' tail') = T.concat ["(", unwordsList head', " . ", showVal tail', ")"]
showVal (PrimitiveFunc _) = "<primitive>"
showVal (StatefulFunc _) = "<ST primitive>"
showVal (Func {params = args, vararg = varargs}) = T.concat
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

-- TODO: non-exhaustive matches (_)
showError :: LispError -> T.Text
showError (NumArgs expected found)      = T.concat ["Expected ", (T.pack . show) expected, " args; found values ", unwordsFixList found]
showError (TypeMismatch expected found) = T.concat ["Invalid type: expected ", expected, ", found ", (T.pack . show) found]
showError (Parser parseErr)             = T.concat ["Parse error at ", (T.pack . show) parseErr]
showError (BadSpecialForm message form) = T.concat [message, ": ", (T.pack . show) form]
showError (UnboundVar message varname)  = T.concat [message, ": ", varname]
showError (NotFunction message func)    = T.concat [message, ": ", func]
showError (Default message)             = T.concat ["Default: ", message]

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
