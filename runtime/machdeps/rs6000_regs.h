/*
** Copyright (C) 1996-1997, 2000 The University of Melbourne.
** This file may only be copied under the terms of the GNU Library General
** Public License - see the file COPYING.LIB in the Mercury distribution.
*/

#ifndef RS6000_REGS_H
#define RS6000_REGS_H

/*
** Machine registers mr0 - mr36 for the RS/6000 architecture.
**
** The first NUM_REAL_REGS of these are real machine registers.
** The others are just slots in a global array.
**
** For the RS/6000, registers r13 to r31 are callee-save.
** Currently we're just using r13-r22 and leaving r23-r31 for gcc.
*/

#define NUM_REAL_REGS 10

register 	MR_Word	mr0 __asm__("r13");
register	MR_Word	mr1 __asm__("r14");
register	MR_Word	mr2 __asm__("r15");
register	MR_Word	mr3 __asm__("r16");
register	MR_Word	mr4 __asm__("r17");
register	MR_Word	mr5 __asm__("r18");
register	MR_Word	mr6 __asm__("r19");
register	MR_Word	mr7 __asm__("r20");
register	MR_Word	mr8 __asm__("r21");
register	MR_Word	mr9 __asm__("r22");

#define save_regs_to_mem(save_area) (		\
	save_area[0] = mr0,			\
	save_area[1] = mr1,			\
	save_area[2] = mr2,			\
	save_area[3] = mr3,			\
	save_area[4] = mr4,			\
	save_area[5] = mr5,			\
	save_area[6] = mr6,			\
	save_area[7] = mr7,			\
	save_area[8] = mr8,			\
	save_area[9] = mr9,			\
	(void)0					\
)

#define restore_regs_from_mem(save_area) (	\
	mr0 = save_area[0],			\
	mr1 = save_area[1],			\
	mr2 = save_area[2],			\
	mr3 = save_area[3],			\
	mr4 = save_area[4],			\
	mr5 = save_area[5],			\
	mr6 = save_area[6],			\
	mr7 = save_area[7],			\
	mr8 = save_area[8],			\
	mr9 = save_area[9],			\
	(void)0					\
)

#define save_transient_regs_to_mem(save_area)		((void)0)
#define restore_transient_regs_from_mem(save_area)	((void)0)

#define	mr10	MR_fake_reg[10]
#define	mr11	MR_fake_reg[11]
#define	mr12	MR_fake_reg[12]
#define	mr13	MR_fake_reg[13]
#define	mr14	MR_fake_reg[14]
#define	mr15	MR_fake_reg[15]
#define	mr16	MR_fake_reg[16]
#define	mr17	MR_fake_reg[17]
#define	mr18	MR_fake_reg[18]
#define	mr19	MR_fake_reg[19]
#define	mr20	MR_fake_reg[20]
#define	mr21	MR_fake_reg[21]
#define	mr22	MR_fake_reg[22]
#define	mr23	MR_fake_reg[23]
#define	mr24	MR_fake_reg[24]
#define	mr25	MR_fake_reg[25]
#define	mr26	MR_fake_reg[26]
#define	mr27	MR_fake_reg[27]
#define	mr28	MR_fake_reg[28]
#define	mr29	MR_fake_reg[29]
#define	mr30	MR_fake_reg[30]
#define	mr31	MR_fake_reg[31]
#define	mr32	MR_fake_reg[32]
#define	mr33	MR_fake_reg[33]
#define	mr34	MR_fake_reg[34]
#define	mr35	MR_fake_reg[35]
#define	mr36	MR_fake_reg[36]
#define	mr37	MR_fake_reg[37]

#endif /* not RS6000_REGS_H */
