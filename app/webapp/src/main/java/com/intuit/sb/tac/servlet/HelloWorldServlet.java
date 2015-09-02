package com.intuit.sb.tac.servlet;


import java.io.IOException;
import java.io.PrintWriter;
import javax.servlet.ServletException;
import javax.servlet.annotation.WebServlet;
import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;


/**
 * Servlet implementation class HelloWorld
 */
@WebServlet("/helloworld")
public class HelloWorldServlet extends HttpServlet {
  private String message;

  public void init() throws ServletException
  {
      // Do required initialization
      message = "Hello World Update #9";
  }

  private static final long serialVersionUID = 1L;
       
  /**
  * @see HttpServlet#doGet(HttpServletRequest request, HttpServletResponse response)
  */
  protected void doGet(HttpServletRequest request, HttpServletResponse response) throws ServletException, IOException {
      try {
          response.setContentType("text/html");

          // Actual logic goes here.
          PrintWriter out = response.getWriter();
          out.println("<h1>" + message + "</h1>");
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
