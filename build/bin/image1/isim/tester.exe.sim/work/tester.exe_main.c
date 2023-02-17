/**********************************************************************/
/*   ____  ____                                                       */
/*  /   /\/   /                                                       */
/* /___/  \  /                                                        */
/* \   \   \/                                                       */
/*  \   \        Copyright (c) 2003-2009 Xilinx, Inc.                */
/*  /   /          All Right Reserved.                                 */
/* /---/   /\                                                         */
/* \   \  /  \                                                      */
/*  \___\/\___\                                                    */
/***********************************************************************/

#include "xsi.h"

struct XSI_INFO xsi_info;



int main(int argc, char **argv)
{
    xsi_init_design(argc, argv);
    xsi_register_info(&xsi_info);

    xsi_register_min_prec_unit(-12);
    tester_m_00000000001276205554_3422518322_init();
    tester_m_00000000000484172124_2546504659_init();
    tester_m_00000000003293221746_3417581967_init();
    tester_m_00000000004101582229_4283313649_init();
    uut_m_00000000001110896336_3738630502_init();
    reference_m_00000000004216948521_0179273198_init();
    tester_m_00000000003258464136_2613777659_init();
    test_m_00000000003363540012_2813505360_init();


    xsi_register_tops("test_m_00000000003363540012_2813505360");


    return xsi_run_simulation(argc, argv);

}
