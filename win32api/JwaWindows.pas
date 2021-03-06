{******************************************************************************}
{                                                                              }
{ Windows API interface Unit for Object Pascal                                 }
{ Master file for Windows applications                                         }
{                                                                              }
{ Portions created by Microsoft are Copyright (C) Microsoft Corporation.       }
{  All Rights Reserved.                                                        }
{                                                                              }
{ The original Pascal code is: JwaWindows.pas, released September 2005.        }
{ The initial developer of the Pascal code is                                  }
{ Robert Marquardt (robert_marquardt att gmx dott de).                         }
{                                                                              }
{ Portions created by Robert Marquardt are Copyright (C) 2005                  }
{ Robert Marquardt. All Rights Reserved.                                       }
{                                                                              }
{ Obtained through: Joint Endeavour of Delphi Innovators (Project JEDI)        }
{                                                                              }
{ You may retrieve the latest version of this file at the Project JEDI         }
{ APILIB home page, located at http://jedi-apilib.sourceforge.net              }
{                                                                              }
{ The contents of this file are used with permission, subject to the Mozilla   }
{ Public License Version 1.1 (the "License"); you may not use this file except }
{ in compliance with the License. You may obtain a copy of the License at      }
{ http://www.mozilla.org/MPL/MPL-1.1.html                                      }
{                                                                              }
{ Software distributed under the License is distributed on an "AS IS" basis,   }
{ WITHOUT WARRANTY OF ANY KIND, either express or implied. See the License for }
{ the specific language governing rights and limitations under the License.    }
{                                                                              }
{ Alternatively, the contents of this file may be used under the terms of the  }
{ GNU Lesser General Public License (the  "LGPL License"), in which case the   }
{ provisions of the LGPL License are applicable instead of those above.        }
{ If you wish to allow use of your version of this file only under the terms   }
{ of the LGPL License and not to allow others to use your version of this file }
{ under the MPL, indicate your decision by deleting  the provisions above and  }
{ replace  them with the notice and other provisions required by the LGPL      }
{ License.  If you do not delete the provisions above, a recipient may use     }
{ your version of this file under either the MPL or the LGPL License.          }
{                                                                              }
{ For more information about the LGPL: http://www.gnu.org/copyleft/lesser.html }
{                                                                              }
{******************************************************************************}

// $Id: JwaWindows.pas,v 1.9 2005/09/07 09:54:54 marquardt Exp $

unit JwaWindows;

{$WEAKPACKAGEUNIT}

{$DEFINE JWAWINDOWS_PAS}
{$DEFINE JWA_INCLUDEMODE}

{$I jediapilib.inc}

interface

uses
  {$IFDEF USE_DELPHI_TYPES}
  Windows,
  {$ENDIF USE_DELPHI_TYPES}
  SysUtils; // TODO

{$DEFINE JWA_INTERFACESECTION}
{$I JwaWinType.pas}
{$I JwaNtStatus.pas}
{$I JwaWinNT.pas}
{$I JwaWinBase.pas}
{$I JwaWinGDI.pas}
{$I JwaWinUser.pas}
{$I JwaDde.pas}
{$I JwaWinVer.pas}
{$I JwaWinError.pas}
{$I JwaExcpt.pas}
{$I JwaWinNLS.pas}
{$I JwaWinCon.pas}
{$I JwaReason.pas}
{$I JwaWinReg.pas}
{$I JwaWinNetWk.pas}
{$I JwaCdErr.pas}
{ I JwaDDEml.pas} // TODO convert
{$I JwaDlgs.pas}
{ I JwaMMSystem.pas} // TODO convert
{$I JwaNb30.pas}
{ I JwaShellAPI.pas} // TODO convert
{$I JwaWinPerf.pas}
{$I JwaWinSock.pas}
{$I JwaWinCrypt.pas}
{$I JwaRpc.pas}
{$I JwaWinEFS.pas}
{ I JwaWinScard.pas} // TODO convert
{ I JwaWinSpool.pas} // TODO convert
{ I JwaOle2.pas} // TODO convert
{ I JwaCommDlg.pas} // TODO convert
{ I JwaStrAlign.pas} // TODO convert
{$I JwaWinSvc.pas}
{ I JwaMCX.pas} // TODO convert
{ I JwaIMM.pas} // TODO convert
{$UNDEF JWA_INTERFACESECTION}

implementation

uses
  JwaWinDLLNames;

{$DEFINE JWA_IMPLEMENTATIONSECTION}
{$I JwaWinType.pas}
{$I JwaNtStatus.pas}
{$I JwaWinNT.pas}
{$I JwaWinBase.pas}
{$I JwaWinGDI.pas}
{$I JwaWinUser.pas}
{$I JwaDde.pas}
{$I JwaWinVer.pas}
{$I JwaWinError.pas}
{$I JwaExcpt.pas}
{$I JwaWinNLS.pas}
{$I JwaWinCon.pas}
{$I JwaReason.pas}
{$I JwaWinReg.pas}
{$I JwaWinNetWk.pas}
{$I JwaCdErr.pas}
{ I JwaDDEml.pas} // TODO convert
{$I JwaDlgs.pas}
{ I JwaMMSystem.pas} // TODO convert
{$I JwaNb30.pas}
{ I JwaShellAPI.pas} // TODO convert
{$I JwaWinPerf.pas}
{$I JwaWinSock.pas}
{$I JwaWinCrypt.pas}
{$I JwaRpc.pas}
{$I JwaWinEFS.pas}
{ I JwaWinScard.pas} // TODO convert
{ I JwaWinSpool.pas} // TODO convert
{ I JwaOle2.pas} // TODO convert
{ I JwaCommDlg.pas} // TODO convert
{ I JwaStrAlign.pas} // TODO convert
{$I JwaWinSvc.pas}
{ I JwaMCX.pas} // TODO convert
{ I JwaIMM.pas} // TODO convert
{$UNDEF JWA_IMPLEMENTATIONSECTION}

end.

