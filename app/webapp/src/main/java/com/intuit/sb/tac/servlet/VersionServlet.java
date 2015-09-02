package com.intuit.sb.tac.servlet;


import java.io.IOException;
import java.io.PrintWriter;
import java.util.Enumeration;
import java.util.Properties;
import javax.servlet.ServletException;
import javax.servlet.annotation.WebServlet;
import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;


/**
 * Servlet implementation class HelloWorld
 */
@WebServlet("/version")
public class VersionServlet extends HttpServlet {
  private String message;

  public void init() throws ServletException
  {
      // Do required initialization
      message = "Hello World";
  }

  private static final long serialVersionUID = 1L;
       
  /**
  * @see HttpServlet#doGet(HttpServletRequest request, HttpServletResponse response)
  */
  protected void doGet(HttpServletRequest request, HttpServletResponse response) throws ServletException, IOException {
      try {
          response.setContentType("text/plain");

          // Actual logic goes here.
          PrintWriter out = response.getWriter();
          try {
              Properties prop = new Properties();
              prop.load(getServletContext().getResourceAsStream("/META-INF/MANIFEST.MF"));

              Enumeration keys = prop.keys();
              while (keys.hasMoreElements()) {
                  String key = (String)keys.nextElement();
                  String value = (String)prop.get(key);
                  out.println(key + ": " + value);
              }

          } finally {
              out.close();
          }
      }
      catch(Exception e){
          e.printStackTrace();
      }
      // TODO Auto-generated method stub
  }

  /**
  * @see HttpServlet#doPost(HttpServletRequest request, HttpServletResponse response)
  */
  protected void doPost(HttpServletRequest request, HttpServletResponse response) throws ServletException, IOException {
      // TODO Auto-generated method stub
  }
}
