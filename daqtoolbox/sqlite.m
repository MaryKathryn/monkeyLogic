classdef sqlite < handle
%SQLITE provides the interfaces to access SQLite databases.
%
%   db = sqlite;
%   db.version
%   db.connect('test.db');
%   db.query('CREATE TABLE Test (Subject TEXT, Score INTEGER);');
%   db.query('INSERT INTO Test (Subject,Score) VALUES (''English'',50);');
%   db.query('INSERT INTO Test (Subject,Score) VALUES (?,?);','Math',90);
%   db.query('UPDATE Test SET Score=80 WHERE Subject=''English'';');
%   table = db.query('SELECT * from Test;');
%   db.query('DELETE FROM Test WHERE Score<90;');
%
%   cell_mat = { uint8('A byte stream in a cell matrix is considered a blob.') };
%   db.query('CREATE TABLE BinaryLargeOBject (Object Blob);');
%   db.query('INSERT INTO BinaryLargeOBject (Object) VALUES (?);',cell_mat);
%
%   clear db;  % This also disconnect DB. 'db.delete' does the same.
%
%   Jun 17, 2015        Written by Jaewon Hwang (jaewon.hwang@gmail.com)
%   Mar  5, 2017        Revised by Jaewon

    methods
        function obj = sqlite(dbname)
            if exist('dbname','var') && 2==exist(dbname,'file'), connect(obj,dbname); end
        end
        function delete(obj)
            disconnect(obj);
        end
        function connect(~, dbname)
            sqlmex(1, dbname);
        end
        function disconnect(~)
            sqlmex(2);
        end
        function table = query(~, str, varargin)
            table = sqlmex(3, str, varargin);
        end
    end
    methods (Static) 
        function ver = version()
            ver = sqlmex(0);
        end
    end
end