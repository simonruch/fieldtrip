function retval = qsublist(cmd, jobid, pbsid)

% QSUBLIST is a helper function that is used to keep track of all the
% jobs in a submitted bacth
%
% Use as
%   qsublist(cmd, jobid, pbsid)
%
% The jobid is the identifier that is used within MATLAB for the file names,
% for example "roboos_mentat242_p4376_b2_j453".
%
% The pbsid is the identifier that is used within the batch queueing system,
% for example "15260.torque"
%
% The following commands can be used by the end-user.
%   'list'
%   'kill'
%   'killall'
%
%
% The following commands are used by QSUBFEVAL and QSUBGET respectively.
%   'add'
%   'del'
%   'completed'
%
% See also QSUBCELLFUN, QSUBFEVAL, QSUBGET

% -----------------------------------------------------------------------
% Copyright (C) 2011, Robert Oostenveld
%
% This program is free software: you can redistribute it and/or modify
% it under the terms of the GNU General Public License as published by
% the Free Software Foundation, either version 3 of the License, or
% (at your option) any later version.
%
% This program is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
% GNU General Public License for more details.
%
% You should have received a copy of the GNU General Public License
% along with this program.  If not, see <http://www.gnu.org/licenses/
%
% $Id$
% -----------------------------------------------------------------------

persistent list_jobid list_pbsid

if nargin<1
  cmd = 'list';
end

if nargin<2
  jobid = [];
end

if nargin<3
  pbsid = [];
end

% FIXME this relies on the default and cannot be overruled at the moment
% see http://bugzilla.fcdonders.nl/show_bug.cgi?id=2430
backend = defaultbackend;

if isempty(jobid) && ~isempty(pbsid)
  % get it from the persistent list
  sel = strmatch(pbsid, list_pbsid);
  if ~isempty(sel)
    jobid = list_jobid{sel};
  end
end

if isempty(pbsid) && ~isempty(jobid)
  % get it from the persistent list
  sel = strmatch(jobid, list_jobid);
  if ~isempty(sel)
    pbsid = list_pbsid{sel};
  end
end

switch cmd
  case 'add'
    % add it to the persistent lists
    list_jobid{end+1} = jobid;
    list_pbsid{end+1} = pbsid;
    
  case 'del'
    sel = strmatch(jobid, list_jobid);
    if ~isempty(sel)
      % remove it from the persistent lists
      list_jobid(sel) = [];
      list_pbsid(sel) = [];
    end
    
  case 'kill'
    sel = strmatch(jobid, list_jobid);
    if ~isempty(sel)
      % remove it from the batch queue
      switch backend
        case 'torque'
          system(sprintf('qdel %s', pbsid));
        case 'sge'
          system(sprintf('qdel %s', pbsid));
        case 'slurm'
          system(sprintf('scancel --name %s', jobid));
        case 'lsf'
          system(sprintf('bkill %s', pbsid));
        case 'local'
          warning('cleaning up local jobs is not supported');
        case 'system'
          warning('cleaning up system jobs is not supported');
      end
      % remove the corresponing files from the shared storage
      system(sprintf('rm -f %s*', jobid));
      % remove it from the persistent lists
      list_jobid(sel) = [];
      list_pbsid(sel) = [];
    end
    
  case 'killall'
    if ~isempty(list_jobid)
      % give an explicit warning, because chances are that the user will see messages from qdel
      % about jobs that have just completed and hence cannot be deleted any more
      warning('cleaning up all scheduled and running jobs, don''t worry if you see warnings from "qdel"');
    end
    % start at the end, work towards the begin of the list
    for i=length(list_jobid):-1:1
      qsublist('kill', list_jobid{i}, list_pbsid{i});
    end
    
  case 'completed'
    % cmd = 'completed' returns whether the job is completed as a boolean
    % when backend-specific syntax is known, it uses the appropriate command, 
    % otherwise it determines it in the old way (based on output and log files)
    switch backend
      case 'torque'
        [dum,jobstatus] = system(['qstat ' pbsid ' -f1 | grep job_state | grep -o "= [A-Z]" | grep -o [A-Z]']);
        if strcmp(strtrim(jobstatus),'C')
          retval = true;
        else
          retval = false;
        end
      case {'sge','slurm','lsf','local','system'}
        curPwd = getcustompwd();
        outputfile   = fullfile(curPwd, sprintf('%s_output.mat', jobid));
        logout       = fullfile(curPwd, sprintf('%s.o*', jobid)); % note the wildcard in the file name
        logerr       = fullfile(curPwd, sprintf('%s.e*', jobid)); % note the wildcard in the file name
        retval = exist(outputfile, 'file') && isfile(logout) && isfile(logerr);
    end
    
  case 'list'
    for i=1:length(list_jobid)
      fprintf('%s %s\n', list_jobid{i}, list_pbsid{i});
    end
    
  case 'getjobid'
    % return the mathing jobid, given the pbsid
    retval = jobid;
    
  case 'getpbsid'
    % return the mathing pbsid, given the jobid
    retval = pbsid;
    
  otherwise
    error('unsupported command (%s)', cmd);
end % switch

