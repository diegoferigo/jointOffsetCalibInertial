
%% Home single step sequence

% For limbs calibration
homeCalibLimbs.labels = {...
    'ctrl','ctrl','ctrl','ctrl','ctrl','ctrl';...
    'pos','pos','pos','pos','pos','pos';
    'left_arm','right_arm','left_leg','right_leg','torso','head'};
homeCalibLimbs.val = {...
    [0 45 0 50 0 0 0],...
    [0 45 0 50 0 0 0],...
    [0 10 0 0 0 0],...
    [0 10 0 0 0 0],...
    [0 0 0],...
    [0 0 0]};

% For torso calibration
homeCalibTorso = homeCalibLimbs;
homeCalibTorso.val = {...
    [-30 30 -30 20 0 0 0],...
    [-30 30 -30 20 0 0 0],...
    [0 10 0 0 0 0],...
    [0 10 0 0 0 0],...
    [0 0 0],...
    [0 0 0]};

%% Motion sequences
% (a single sequence is intended to move all defined parts synchronously,
% motions from 2 different sequences should be run asynchronously)
% each calibPart should be caibrated within a single sequence.

% define tables for each limb
left_arm_seqParams.labels = {...
    'ctrl'               ,'ctrl'          ,'meas'     ,'meas'     ,'meas'     ;...
    'pos'                ,'vel'           ,'joint'    ,'joint'    ,'acc'      ;...
    'left_arm'           ,'left_arm'      ,'left_arm' ,'torso'    ,'left_arm'};
left_arm_seqParams.val = {...
    [  0 45 -23 50 0 0 0],repmat( 4,[1 7]),true       ,true       ,true       ;...
    [  0 45  49 50 0 0 0],repmat( 4,[1 7]),true       ,true       ,true       ;...
    [  0 45   0 50 0 0 0],repmat( 4,[1 7]),true       ,true       ,true       ;...
    [-20 30 -30 90 0 0 0],repmat(10,[1 7]),false      ,false      ,false      ;...
    [-20 30 -30  0 0 0 0],repmat( 4,[1 7]),true       ,true       ,true       ;...
    [-20 30 -30 90 0 0 0],repmat( 4,[1 7]),true       ,true       ,true       ;...
    [ 0  45   0 50 0 0 0],repmat(10,[1 7]),false      ,false      ,false      ;...
    [ 0  45   0 50 0 0 0],repmat(10,[1 7]),false      ,false      ,false      };

right_arm_seqParams.labels = {...
    'ctrl'               ,'ctrl'          ,'meas'     ,'meas'     ,'meas'      ;...
    'pos'                ,'vel'           ,'joint'    ,'joint'    ,'acc'       ;...
    'right_arm'          ,'right_arm'     ,'right_arm','torso'    ,'right_arm'};
right_arm_seqParams.val = left_arm_seqParams.val;

left_leg_seqParams.labels = {...
    'ctrl'                 ,'ctrl'          ,'meas'    ,'meas'    ;...
    'pos'                  ,'vel'           ,'joint'   ,'acc'     ;...
    'left_leg'             ,'left_leg'      ,'left_leg','left_leg'};
left_leg_seqParams.val = {...
    [ 0 45 -60   0   0   0],repmat(10,[1 6]),false     ,false     ;...
    [ 0 45  60   0   0   0],repmat( 4,[1 6]),true      ,true      ;...
    [80 30   0   0   0   0],repmat(10,[1 6]),false     ,false     ;...
    [80 30   0 -80   0   0],repmat( 4,[1 6]),true      ,true      ;...
    [80 30   0 -80 -25   0],repmat( 2,[1 6]),true      ,true      ;...
    [80 30   0 -80  25   0],repmat( 2,[1 6]),true      ,true      ;...
    [80 30   0 -80   0 -20],repmat( 2,[1 6]),true      ,true      ;...
    [80 30   0 -80   0  20],repmat( 2,[1 6]),true      ,true      };
    
right_leg_seqParams.labels = {...
    'ctrl'               ,'ctrl'          ,'meas'     ,'meas'     ;...
    'pos'                ,'vel'           ,'joint'    ,'acc'      ;...
    'right_leg'          ,'right_leg'     ,'right_leg','right_leg'};
right_leg_seqParams.val = left_leg_seqParams.val;

torso_seqParams.labels = {...
    'ctrl'    ,'ctrl'          ,'meas'     ,'meas' ;...
    'pos'     ,'vel'           ,'joint'    ,'acc'  ;...
    'torso'   ,'torso'         ,'torso'    ,'torso'};
torso_seqParams.val = {...
    [  0 0 45],repmat(10,[1 3]),false      ,false  ;...
    [-45 0 45],repmat( 4,[1 3]),true       ,true   ;...
    [ 45 0 45],repmat( 4,[1 3]),true       ,true   ;...
    [-45 0 45],repmat( 4,[1 3]),true       ,true   ;...
    [ 45 0 45],repmat( 4,[1 3]),true       ,true   ;...
    [  0 0 45],repmat( 4,[1 3]),true       ,true   ;...
    [  0 0 45],repmat(10,[1 3]),false      ,false  ;...
    [  0 0 45],repmat(10,[1 3]),false      ,false  };

head_seqParams.labels = {...
    'ctrl'       ,'ctrl'          ,'meas'     ,'meas'     ,'meas';...
    'pos'        ,'vel'           ,'joint'    ,'joint'    ,'imu' ;...
    'head'       ,'head'          ,'head'     ,'torso'    ,'head'};
head_seqParams.val = {...
    [  0 -20   0],repmat( 4,[1 3]),true       ,true       ,true  ;...
    [  0  20   0],repmat( 4,[1 3]),true       ,true       ,true  ;...
    [  0   0   0],repmat( 4,[1 3]),true       ,true       ,true  ;...
    [-25   0   0],repmat( 4,[1 3]),true       ,true       ,true  ;...
    [-25   0 -45],repmat( 4,[1 3]),true       ,true       ,true  ;...
    [-25   0  45],repmat( 4,[1 3]),true       ,true       ,true  ;...
    [-25   0   0],repmat( 4,[1 3]),true       ,true       ,true  ;...
    [  0   0   0],repmat(10,[1 3]),false      ,false      ,false };

% define sequences for limbs {1} and torso {2} calibration
seqHomeParams{1} = homeCalibLimbs;
seqHomeParams{2} = homeCalibTorso;
seqEndParams     = homeCalibLimbs;

% Map parts to sequences and params
selector.calibedParts = {...
    'left_arm','right_arm',...
    'left_leg','right_leg',...
    'torso','head'};
selector.calibedSensors = {...
    {'joint'},{'joint'},...
    {'joint'},{'joint'},...
    {'joint'},{'joint'}};
selector.setIdx  = {2,2,2,2,1,2}; % max index must not exceed max index of seqHomePArams
selector.seqParams = {...
    left_arm_seqParams,right_arm_seqParams,...
    left_leg_seqParams,right_leg_seqParams,...
    torso_seqParams,head_seqParams};
