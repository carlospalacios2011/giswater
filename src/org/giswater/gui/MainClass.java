/*
 * This file is part of Giswater
 * Copyright (C) 2013 Tecnics Associats
 * 
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 * 
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 * 
 * You should have received a copy of the GNU General Public License
 * along with this program. If not, see <http://www.gnu.org/licenses/>.
 * 
 * Author:
 *   David Erill <derill@giswater.org>
 */
package org.giswater.gui;

import java.util.Locale;

import javax.swing.UIManager;

import org.giswater.controller.MenuController;
import org.giswater.dao.MainDao;
import org.giswater.gui.frame.MainFrame;
import org.giswater.util.Utils;


public class MainClass {

    public static MainFrame mdi;

    
    public static void main(String[] args) {
    	
        java.awt.EventQueue.invokeLater(new Runnable() {
			@Override
            public void run() {		
				
            	// Set locale
            	final Locale english = new Locale("en", "EN");
            	Locale.setDefault(english);
            	
            	// Look&Feel
            	//String className = "com.sun.java.swing.plaf.windows.WindowsClassicLookAndFeel";
            	String className = UIManager.getSystemLookAndFeelClassName();
            	try {
        			UIManager.setLookAndFeel(className);
        		} catch (Exception e) {
        			Utils.logError(e.getMessage());
        			return;
        		}  

            	// Initial configuration
				String versionCode = MainClass.class.getPackage().getImplementationVersion();
				String msg = "Application started";
				if (versionCode != null){
					msg+= "\nVersion: " + versionCode;
				}
				Utils.getLogger().info(msg);				
            	if (!MainDao.configIni()){
            		return;
            	}            	
				
            	// Create MainFrame and Menu controller
            	mdi = new MainFrame(MainDao.isConnected(), versionCode);            	
            	MenuController menuController = new MenuController(mdi, versionCode);            	
                mdi.setVisible(true);
                
                // By default open last gsw
                menuController.gswOpen(false);
                
            }
        });

    }
    
    
}